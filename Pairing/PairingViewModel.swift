import Foundation
import SwiftUI
import Combine

class PairingViewModel: ObservableObject {
    @Published var status: String = "Searching for PCs..."
    @Published var showUSBAlert = false
    @Published var pairingFileSaved = false
    @Published var discoveredPCs: [String: URL] = [:]
    @Published var errorMessage: String?
    @Published var isSearchingForServices: Bool = true

    private let serviceBrowser = ServiceBrowser()
    private var manualPCs: [String: URL] = [:]
    private var cancellables = Set<AnyCancellable>()

    init() {
        serviceBrowser.startBrowsing()
        serviceBrowser.$discoveredPCs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] autoPCs in
                guard let self else { return }
                self.isSearchingForServices = autoPCs.isEmpty && self.manualPCs.isEmpty
                self.discoveredPCs = autoPCs.merging(self.manualPCs) { (_, new) in new }
            }
            .store(in: &cancellables)
    }

    func requestPairing(for pcName: String) {
        guard let pcURL = discoveredPCs[pcName] else {
            status = "PC not found"
            errorMessage = "No network service matches \(pcName)."
            return
        }
        
        let deviceName = UIDevice.current.name
        let currentUDID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        let requestBody: [String: String] = [
            "udid": currentUDID,
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
                    self.savePairingFile(data: data, udid: currentUDID)
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
                        self.errorMessage = errorMsg
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
            errorMessage = "Enter a valid IP address."
            return nil
        }

        guard let url = Self.url(from: trimmedIP) else {
            errorMessage = "Unable to parse IP address."
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

    private static func url(from input: String) -> URL? {
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
            components.port = 5000
        }

        if components.host == nil || components.host?.isEmpty == true {
            return nil
        }

        if components.path.isEmpty {
            components.path = "/"
        }

        return components.url
    }

    private func savePairingFile(data: Data, udid: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(udid).mobiledevicepairing")
        try? data.write(to: fileURL)
    }
}
