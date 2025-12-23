import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var storedUDID: String
    @Binding var isOnboardingComplete: Bool
    
    @State private var showingResetConfirmation = false
    @State private var showingRefreshSheet = false
    @State private var refreshServerIP: String = ""
    @State private var isRefreshing = false
    @State private var refreshError: String?
    @State private var refreshedDevice: (udid: String, name: String)?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device UDID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if storedUDID.isEmpty {
                            Text("Not configured")
                                .font(.body)
                                .foregroundColor(.orange)
                        } else {
                            Text(storedUDID)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Device Identity")
                } footer: {
                    Text("This is the hardware UDID fetched from your PC during setup. It's used to identify your device when requesting pairing files.")
                }
                
                Section {
                    Button {
                        showingRefreshSheet = true
                    } label: {
                        Label("Refresh UDID", systemImage: "arrow.clockwise")
                    }
                    
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset Device Identity", systemImage: "trash")
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Resetting will clear your stored UDID and require you to complete onboarding again.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Pairing v1.0")
                            .font(.body)
                        
                        Text("Creates pairing files for iOS devices to connect with a PC. Requires initial USB connection to establish trust.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Reset Device Identity?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    storedUDID = ""
                    isOnboardingComplete = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your stored UDID and you'll need to connect via USB again to complete setup.")
            }
            .sheet(isPresented: $showingRefreshSheet) {
                refreshUDIDSheet
            }
        }
    }
    
    private var refreshUDIDSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Refresh UDID")
                    .font(.title2.weight(.bold))
                
                Text("Connect your iPhone to the PC via USB to refresh your device identity.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                TextField("PC IP Address (e.g., 192.168.1.100)", text: $refreshServerIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 40)
                
                if let error = refreshError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                if let device = refreshedDevice {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Found: \(device.name)")
                            .font(.headline)
                        
                        Text("UDID: \(String(device.udid.prefix(16)))...")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        
                        Button("Use This Device") {
                            storedUDID = device.udid
                            showingRefreshSheet = false
                            refreshedDevice = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    Button {
                        refreshUDID()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .frame(width: 100)
                        } else {
                            Text("Check USB")
                                .frame(width: 100)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRefreshing || refreshServerIP.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Refresh UDID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingRefreshSheet = false
                        refreshedDevice = nil
                        refreshError = nil
                    }
                }
            }
        }
    }
    
    private func refreshUDID() {
        isRefreshing = true
        refreshError = nil
        refreshedDevice = nil
        
        let trimmedIP = refreshServerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = buildURL(from: trimmedIP)?.appendingPathComponent("usb_check") else {
            isRefreshing = false
            refreshError = "Invalid server address"
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRefreshing = false
                
                if let error = error {
                    self.refreshError = "Connection failed: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let devices = json["devices"] as? [[String: Any]],
                      !devices.isEmpty else {
                    self.refreshError = "No device connected via USB"
                    return
                }
                
                let deviceData = devices[0]
                if let udid = deviceData["udid"] as? String {
                    self.refreshedDevice = (
                        udid: udid,
                        name: deviceData["name"] as? String ?? "Unknown Device"
                    )
                } else {
                    self.refreshError = "Invalid response from server"
                }
            }
        }.resume()
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
            components.port = 5000
        }
        
        return components.url
    }
}

#Preview {
    SettingsView(
        storedUDID: .constant("00008101-00196CE930E1401E"),
        isOnboardingComplete: .constant(true)
    )
}
