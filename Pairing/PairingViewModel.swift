import Foundation
import SwiftUI
import Combine

/// Represents the current state of the pairing flow
enum PairingState: Equatable {
    case selectPC
    case connecting(pcName: String)
    case awaitingUSB(pcName: String, message: String)
    case success(fileURL: URL)
    case error(PairingError)
    
    static func == (lhs: PairingState, rhs: PairingState) -> Bool {
        switch (lhs, rhs) {
        case (.selectPC, .selectPC):
            return true
        case (.connecting(let a), .connecting(let b)):
            return a == b
        case (.awaitingUSB(let a, let msgA), .awaitingUSB(let b, let msgB)):
            return a == b && msgA == msgB
        case (.success(let a), .success(let b)):
            return a == b
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

/// Discovered PC model
struct DiscoveredPC: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
    let isManual: Bool
    
    var displayAddress: String {
        url.host ?? "Unknown"
    }
}

@MainActor
class PairingViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published private(set) var state: PairingState = .selectPC
    @Published private(set) var discoveredPCs: [DiscoveredPC] = []
    @Published private(set) var isSearching: Bool = false
    @Published var selectedPCId: String?
    
    // MARK: - Private Properties
    
    let serviceBrowser = ServiceBrowser()
    private var manualPCs: [String: URL] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var usbPollTask: Task<Void, Never>?
    private var hasStartedBrowsing = false
    
    // MARK: - Computed Properties
    
    var selectedPC: DiscoveredPC? {
        discoveredPCs.first { $0.id == selectedPCId }
    }
    
    var canConnect: Bool {
        selectedPCId != nil && state == .selectPC
    }
    
    var currentError: PairingError? {
        if case .error(let error) = state {
            return error
        }
        return nil
    }
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        
        // Start discovery after a brief delay for UI to load
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            startDiscovery()
        }
    }
    
    private func setupBindings() {
        serviceBrowser.$discoveredPCs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] autoPCs in
                self?.updateDiscoveredPCs(autoPCs: autoPCs)
            }
            .store(in: &cancellables)
    }
    
    private func updateDiscoveredPCs(autoPCs: [String: URL]) {
        var pcs: [DiscoveredPC] = []
        
        // Add discovered PCs
        for (name, url) in autoPCs {
            pcs.append(DiscoveredPC(id: name, name: name, url: url, isManual: false))
        }
        
        // Add manual PCs
        for (name, url) in manualPCs {
            pcs.append(DiscoveredPC(id: name, name: name, url: url, isManual: true))
        }
        
        // Sort by name
        discoveredPCs = pcs.sorted { $0.name < $1.name }
        
        // Stop searching indicator when we find something
        if !pcs.isEmpty {
            isSearching = false
        }
    }
    
    // MARK: - Discovery
    
    func startDiscovery() {
        guard !hasStartedBrowsing else {
            refreshDiscovery()
            return
        }
        hasStartedBrowsing = true
        isSearching = true
        serviceBrowser.startBrowsing()
        
        // Stop searching after timeout
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Constants.discoveryTimeout * 1_000_000_000))
            if discoveredPCs.isEmpty {
                isSearching = false
            }
        }
    }
    
    func refreshDiscovery() {
        isSearching = true
        serviceBrowser.startBrowsing()
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Constants.discoveryTimeout * 1_000_000_000))
            isSearching = false
        }
    }
    
    // MARK: - Manual PC Entry
    
    func addManualPC(ip: String) -> Bool {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else { return false }
        
        guard let url = buildURL(from: trimmedIP) else {
            state = .error(.invalidServerURL)
            return false
        }
        
        let key = trimmedIP
        manualPCs[key] = url
        updateDiscoveredPCs(autoPCs: serviceBrowser.discoveredPCs)
        
        // Auto-select the newly added PC
        selectedPCId = key
        
        // Persist manual IPs
        saveManualIPs()
        
        return true
    }
    
    func removeManualPC(id: String) {
        manualPCs.removeValue(forKey: id)
        updateDiscoveredPCs(autoPCs: serviceBrowser.discoveredPCs)
        if selectedPCId == id {
            selectedPCId = nil
        }
        saveManualIPs()
    }
    
    private func saveManualIPs() {
        let ips = Array(manualPCs.keys)
        UserDefaults.standard.set(ips, forKey: Constants.StorageKeys.savedManualIPs)
    }
    
    func loadSavedManualIPs() {
        guard let ips = UserDefaults.standard.array(forKey: Constants.StorageKeys.savedManualIPs) as? [String] else {
            return
        }
        for ip in ips {
            _ = addManualPC(ip: ip)
        }
    }
    
    // MARK: - Pairing
    
    func connect() {
        guard let pc = selectedPC else {
            state = .error(.noServerSelected)
            return
        }
        
        state = .connecting(pcName: pc.name)
        
        Task {
            await requestPairing(pc: pc)
        }
    }
    
    private func requestPairing(pc: DiscoveredPC) async {
        let deviceName = UIDevice.current.name
        let udid = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        let requestBody: [String: String] = [
            "udid": udid,
            "request": "pairing_file",
            "device_name": deviceName
        ]
        
        let url = pc.url.appendingPathComponent("request_pairing")
        
        var request = URLRequest(url: url, timeoutInterval: Constants.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                state = .error(.invalidResponse)
                return
            }
            
            if httpResponse.statusCode == 200 {
                let actualUDID = httpResponse.value(forHTTPHeaderField: "X-Device-UDID") ?? udid
                if let fileURL = savePairingFile(data: data, udid: actualUDID) {
                    triggerSuccessHaptic()
                    state = .success(fileURL: fileURL)
                } else {
                    state = .error(.fileWriteFailed)
                }
                return
            }
            
            // Handle error responses
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                if httpResponse.statusCode == 503 || errorMsg.localizedCaseInsensitiveContains("USB") {
                    state = .awaitingUSB(pcName: pc.name, message: errorMsg)
                    startUSBPolling(pc: pc, udid: udid)
                } else {
                    state = .error(.serverError(errorMsg))
                }
            } else {
                state = .error(.serverError("Server returned status \(httpResponse.statusCode)"))
            }
            
        } catch is CancellationError {
            state = .error(.cancelled)
        } catch {
            state = .error(.networkError(error))
        }
    }
    
    // MARK: - USB Polling
    
    private func startUSBPolling(pc: DiscoveredPC, udid: String) {
        usbPollTask?.cancel()
        
        usbPollTask = Task {
            var attempts = 0
            
            while attempts < Constants.maxUSBPollAttempts && !Task.isCancelled {
                attempts += 1
                
                try? await Task.sleep(nanoseconds: UInt64(Constants.usbPollInterval * 1_000_000_000))
                
                if Task.isCancelled { break }
                
                // Check USB status
                let statusURL = pc.url.appendingPathComponent("usb_status")
                let request = URLRequest(url: statusURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
                
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let udids = json["connected_udids"] as? [String],
                       !udids.isEmpty {
                        // Device connected via USB, retry pairing
                        await requestPairing(pc: pc)
                        return
                    }
                } catch {
                    // Ignore polling errors, continue trying
                }
            }
            
            // Polling timed out
            if !Task.isCancelled {
                state = .error(.usbTimeout)
            }
        }
    }
    
    // MARK: - Actions
    
    func cancel() {
        usbPollTask?.cancel()
        usbPollTask = nil
        state = .selectPC
    }
    
    func reset() {
        usbPollTask?.cancel()
        usbPollTask = nil
        state = .selectPC
        selectedPCId = nil
    }
    
    func dismissError() {
        state = .selectPC
    }
    
    // MARK: - Helpers
    
    private func buildURL(from input: String) -> URL? {
        var candidate = input
        if !candidate.contains("://") {
            candidate = "http://\(candidate)"
        }
        
        guard var components = URLComponents(string: candidate) else {
            return nil
        }
        
        if components.scheme == nil {
            components.scheme = "http"
        }
        
        if components.port == nil {
            components.port = Constants.defaultPort
        }
        
        guard components.host != nil && !components.host!.isEmpty else {
            return nil
        }
        
        return components.url
    }
    
    private func savePairingFile(data: Data, udid: String) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(udid).mobiledevicepairing")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
