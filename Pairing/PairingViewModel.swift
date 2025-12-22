import Foundation
import SwiftUI

class PairingViewModel: ObservableObject {
    @Published var status: String = "Searching for PCs..."
    @Published var showUSBAlert = false
    @Published var pairingFileSaved = false

    private let serviceBrowser = ServiceBrowser()

    init() {
        serviceBrowser.startBrowsing()
    }

    func requestPairing(for pcName: String) {
        guard let pcURL = serviceBrowser.discoveredPCs[pcName] else {
            status = "PC not found"
            return
        }

        let udid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let requestBody = ["udid": udid]

        guard let url = URL(string: "request_pairing", relativeTo: pcURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        status = "Requesting pairing from \(pcName)..."
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = "Error: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data {
                        // Assume it's the pairing file
                        self.savePairingFile(data: data, udid: udid)
                        self.status = "Pairing file received and saved from \(pcName)"
                        self.pairingFileSaved = true
                    } else if let data = data,
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let errorMsg = json["error"] as? String {
                        if errorMsg.contains("Failed to generate") {
                            self.showUSBAlert = true
                            self.status = "Connect USB to \(pcName) for pairing"
                        } else {
                            self.status = "Error: \(errorMsg)"
                        }
                    } else {
                        self.status = "Unknown response from \(pcName)"
                    }
                }
            }
        }.resume()
    }

    private func savePairingFile(data: Data, udid: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(udid).mobiledevicepairing")
        try? data.write(to: fileURL)
    }
}