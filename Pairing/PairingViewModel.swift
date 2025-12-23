import Foundation
import SwiftUI
import Combine

class PairingViewModel: ObservableObject {
    @Published var status: String = "Searching for PCs..."
    @Published var showUSBAlert = false
    @Published var pairingFileSaved = false
    @Published var pairingFileURL: URL?
    @Published var discoveredPCs: [String: URL] = [:]
    @Published var errorMessage: String?
    @Published var isSearchingForServices: Bool = true
    @Published var showDebugLogs: Bool = false
    
    /// The stored hardware UDID fetched during onboarding. This is passed in from ContentView's @AppStorage.
    var storedUDID: String = ""

    let serviceBrowser = ServiceBrowser()
    private var manualPCs: [String: URL] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var usbRetryRemaining = 0
    private var usbRetryTarget: (pcName: String, baseURL: URL, udid: String)?
    private var hasStartedBrowsing = false

    init() {
        print("📱 PairingViewModel initialized")
        
        // Don't start browsing immediately - wait for user action to trigger permission
        serviceBrowser.$discoveredPCs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] autoPCs in
                guard let self else { return }
                print("📡 Discovered PCs updated: \(autoPCs.count) found")
                self.discoveredPCs = autoPCs.merging(self.manualPCs) { (_, new) in new }
                
                // Stop showing searching indicator after we find something
                if !autoPCs.isEmpty {
                    self.isSearchingForServices = false
                    self.status = "Found \(autoPCs.count) PC(s)"
                }
            }
            .store(in: &cancellables)
        
        // Start discovery automatically but after a delay to ensure UI is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startInitialDiscovery()
        }
    }
    
    private func startInitialDiscovery() {
        guard !hasStartedBrowsing else { return }
        hasStartedBrowsing = true
        print("🚀 Starting initial discovery (this should trigger Local Network permission)")
        serviceBrowser.startBrowsing()
        
        // Stop searching indicator after 10 seconds and update status
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.discoveredPCs.isEmpty {
                self.isSearchingForServices = false
                if !self.serviceBrowser.hasPermission {
                    self.status = "Discovery failed. Check permissions below."
                    self.errorMessage = "Go to Settings → Pairing → Local Network and enable it"
                    self.showDebugLogs = true
                } else if self.serviceBrowser.searchFailed {
                    self.status = "Network discovery unavailable"
                    self.errorMessage = "Use Manual PC Entry below"
                    self.showDebugLogs = true
                } else {
                    self.status = "No PCs found on this network"
                    self.errorMessage = "Make sure the server is running and you're on the same WiFi"
                    self.showDebugLogs = true
                }
            }
        }
    }

    func refreshDiscovery() {
        isSearchingForServices = true
        serviceBrowser.startBrowsing()
    }

    func requestPairing(for pcName: String) {
        guard !storedUDID.isEmpty else {
            status = "Complete setup first"
            errorMessage = "Connect via USB to fetch your device UDID from the PC, then retry."
            return
        }

        guard let pcURL = discoveredPCs[pcName] else {
            status = "PC not found"
            errorMessage = "No network service matches \(pcName)."
            return
        }
        
        let deviceName = UIDevice.current.name

        let requestBody: [String: String] = [
            "udid": storedUDID,
            "request": "pairing_file",
            "device_name": deviceName
        ]
        
        let url = pcURL.appendingPathComponent("request_pairing")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        status = "Requesting pairing from \(pcName)..."
        errorMessage = nil
        pairingFileSaved = false
        pairingFileURL = nil
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = "Error: \(error.localizedDescription)"
                    self.errorMessage = "\(error.localizedDescription) — URL: \(url.absoluteString)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.status = "Unexpected response"
                    self.errorMessage = "Pairing server response was invalid."
                    return
                }

                if httpResponse.statusCode == 200, let data = data {
                    let actualUDID = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Device-UDID") ?? self.storedUDID
                    self.savePairingFile(data: data, udid: actualUDID)
                    self.status = "Pairing file received and saved from \(pcName)"
                    self.pairingFileSaved = true
                    self.errorMessage = nil
                    return
                }

                // Handle JSON error payloads (e.g., USB required)
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = json["error"] as? String {
                    if httpResponse.statusCode == 503 || errorMsg.localizedCaseInsensitiveContains("USB") {
                        self.showUSBAlert = true
                        self.status = "Connect USB to \(pcName) for pairing"
                        if let connected = json["connected_udids"] as? [String], !connected.isEmpty {
                            self.errorMessage = "USB mismatch. Connected: \(connected.joined(separator: ", "))"
                        } else {
                            self.errorMessage = errorMsg
                        }
                        self.startUSBWait(pcName: pcName, udid: self.storedUDID, baseURL: pcURL)
                    } else {
                        self.status = "Error while pairing"
                        self.errorMessage = errorMsg
                    }
                    return
                }

                self.status = "Unknown response from \(pcName)"
                self.errorMessage = "Server returned code \(httpResponse.statusCode). URL: \(url.absoluteString)"
            }
        }.resume()
    }

    func addManualPC(ip: String) -> String? {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else {
            errorMessage = "Enter an IPv4 address."
            return nil
        }

        guard let url = Self.ipv4URL(from: trimmedIP) else {
            errorMessage = "Use numeric IPv4 only, e.g. 192.168.1.10:5000"
            return nil
        }

        let key = "Manual PC (\(trimmedIP))"
        manualPCs[key] = url
        discoveredPCs = serviceBrowser.discoveredPCs.merging(manualPCs) { (_, new) in new }
        isSearchingForServices = serviceBrowser.discoveredPCs.isEmpty && manualPCs.isEmpty
        status = "Added manual PC \(trimmedIP)"
        errorMessage = nil
        return key
    }

    private static func ipv4URL(from input: String) -> URL? {
        // Accept forms like 192.168.1.10 or 192.168.1.10:5000
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard let hostPart = parts.first, isValidIPv4(String(hostPart)) else { return nil }
        let portPart = parts.count == 2 ? parts[1] : "5000"
        guard let port = Int(portPart), (1...65535).contains(port) else { return nil }
        return URL(string: "http://\(hostPart):\(port)")
    }

    private static func isValidIPv4(_ text: String) -> Bool {
        let comps = text.split(separator: ".")
        guard comps.count == 4 else { return false }
        return comps.allSatisfy { part in
            guard let n = Int(part), (0...255).contains(n) else { return false }
            // Prevent leading plus/minus and empty segments
            return String(n) == part
        }
    }

    private func startUSBWait(pcName: String, udid: String, baseURL: URL) {
        usbRetryRemaining = 10
        usbRetryTarget = (pcName, baseURL, udid)
        status = "Waiting for USB on \(pcName)..."
        pollUSBAndRetry()
    }

    private func pollUSBAndRetry() {
        guard usbRetryRemaining > 0, let target = usbRetryTarget else { return }
        usbRetryRemaining -= 1

        let statusURL = target.baseURL.appendingPathComponent("usb_status")
        let req = URLRequest(url: statusURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 3)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let udids = json["connected_udids"] as? [String],
                   !udids.isEmpty {
                    // If requested udid not present but some device is connected, allow retry to proceed (server can choose the connected one)
                    self.usbRetryTarget = nil
                    self.requestPairing(for: target.pcName)
                    return
                }

                // Schedule another poll if attempts remain
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.pollUSBAndRetry()
                }
            }
        }.resume()
    }

    private func savePairingFile(data: Data, udid: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(udid).mobiledevicepairing")
        try? data.write(to: fileURL)
        DispatchQueue.main.async {
            self.pairingFileURL = fileURL
        }
    }
}
