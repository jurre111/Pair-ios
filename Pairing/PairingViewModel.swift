import Foundation
import SwiftUI
import Combine

struct SavedPC: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let isManual: Bool
}

/// Represents the current state of the pairing flow
enum PairingState: Equatable {
    case selectPC
    case connecting(pcName: String)
    case awaitingUSB(pcName: String, message: String)
    case success(fileURL: URL)
    case error(PairingError)

    var isAwaitingUSBState: Bool {
        if case .awaitingUSB = self { return true }
        return false
    }
    
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
    @Published private(set) var savedPCs: [SavedPC] = []
    
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
        selectedPC != nil && state == .selectPC
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
        loadSavedPCs()
        
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

        if let selected = selectedPCId,
           !discoveredPCs.contains(where: { $0.id == selected }) {
            selectedPCId = nil
        }
        
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

        saveSavedPC(from: DiscoveredPC(id: key, name: trimmedIP, url: url, isManual: true))
        
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
        removeSavedPC(id: id)
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
        
        saveSavedPC(from: pc)
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
        savedPCs.removeAll()
        manualPCs.removeAll()
        saveManualIPs()
        persistSavedPCs()
        updateDiscoveredPCs(autoPCs: serviceBrowser.discoveredPCs)
    }
    
    func dismissError() {
        state = .selectPC
    }
    
    // MARK: - Helpers

    func selectPC(_ pc: DiscoveredPC) {
        selectedPCId = pc.id
        saveSavedPC(from: pc)
    }

    private func saveSavedPC(from pc: DiscoveredPC) {
        let address = pc.url.host ?? pc.id
        let newSaved = SavedPC(id: address, name: pc.name, address: address, isManual: pc.isManual)

        if let index = savedPCs.firstIndex(where: { $0.id == newSaved.id }) {
            savedPCs[index] = newSaved
        } else {
            savedPCs.append(newSaved)
        }
        persistSavedPCs()
    }

    func removeSavedPC(id: String) {
        savedPCs.removeAll { $0.id == id }
        persistSavedPCs()
    }

    func availableSavedPCs() -> [SavedPC] {
        savedPCs.filter { saved in
            if saved.isManual { return manualPCs[saved.id] != nil }
            return discoveredPCs.contains { $0.displayAddress == saved.address || $0.id == saved.id || $0.name == saved.name }
        }
    }

    func isSavedPCAvailable(_ pc: SavedPC) -> Bool {
        if pc.isManual {
            return manualPCs[pc.id] != nil
        }
        return discoveredPCs.contains { $0.displayAddress == pc.address || $0.id == pc.id || $0.name == pc.name }
    }

    private func persistSavedPCs() {
        if let data = try? JSONEncoder().encode(savedPCs) {
            UserDefaults.standard.set(data, forKey: Constants.StorageKeys.savedPCs)
        }
    }

    private func loadSavedPCs() {
        guard let data = UserDefaults.standard.data(forKey: Constants.StorageKeys.savedPCs),
              let decoded = try? JSONDecoder().decode([SavedPC].self, from: data) else { return }
        savedPCs = decoded
    }
    
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
