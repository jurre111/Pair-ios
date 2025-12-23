import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @Binding var storedUDID: String
    
    @State private var currentStep = 0
    @State private var isCheckingUSB = false
    @State private var errorMessage: String?
    @State private var fetchedDevice: DeviceInfo?
    @State private var discoveredServers: [String: URL] = [:]
    @State private var selectedServer: String?
    
    @StateObject private var serviceBrowser = ServiceBrowser()
    
    struct DeviceInfo {
        let udid: String
        let name: String
        let trusted: Bool
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<2) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Spacer()
                
                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        connectUSBStep
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                                errorMessage = nil
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < 1 {
                        Button("Next") {
                            withAnimation {
                                advanceStep()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                serviceBrowser.startBrowsing()
            }
            .onChange(of: serviceBrowser.discoveredPCs) { newValue in
                discoveredServers = newValue
            }
        }
    }
    
    private func advanceStep() {
        switch currentStep {
        case 0:
            currentStep = 1
            // Start checking for USB device immediately
            checkUSBDevice()
        default:
            break
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "cable.connector")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Pairing")
                .font(.largeTitle.weight(.bold))
            
            Text("This app helps you create pairing files for your iOS device to connect with a PC.\n\nMake sure the Pairing Server is running on your PC, then tap Next to connect via USB.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var connectUSBStep: some View {
        VStack(spacing: 24) {
            if isCheckingUSB {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 20)
                
                Text("Looking for your device...")
                    .font(.title2.weight(.semibold))
                
                Text("Connect your iPhone to the PC via USB cable and tap 'Trust' when prompted.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if let device = fetchedDevice {
                Image(systemName: device.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(device.trusted ? .green : .orange)
                
                Text(device.trusted ? "Device Found!" : "Trust Required")
                    .font(.largeTitle.weight(.bold))
                
                VStack(spacing: 8) {
                    Text(device.name)
                        .font(.title3.weight(.medium))
                    
                    Text("UDID: \(String(device.udid.prefix(12)))...")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                
                if device.trusted {
                    Button("Complete Setup") {
                        storedUDID = device.udid
                        isOnboardingComplete = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Text("Tap 'Trust' on the prompt that appeared on this device, then tap Retry.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Retry") {
                        checkUSBDevice()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Image(systemName: "cable.connector")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Connect via USB")
                    .font(.largeTitle.weight(.bold))
                
                Text("Connect your iPhone to the PC via USB cable.\n\nWhen prompted, tap 'Trust This Computer' on this device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button("Check Connection") {
                    checkUSBDevice()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - USB Check
    
    private func checkUSBDevice() {
        isCheckingUSB = true
        errorMessage = nil
        fetchedDevice = nil
        
        // Try all discovered servers
        guard !discoveredServers.isEmpty else {
            isCheckingUSB = false
            errorMessage = "No server found. Make sure the Pairing Server is running on your PC and you're on the same Wi-Fi."
            return
        }
        
        // Try the first discovered server
        let serverURL = Array(discoveredServers.values)[0]
        guard let url = serverURL.appendingPathComponent("usb_check") as URL? else {
            isCheckingUSB = false
            errorMessage = "Invalid server address"
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isCheckingUSB = false
                
                if let error = error {
                    self.errorMessage = "Connection failed: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let devices = json["devices"] as? [[String: Any]],
                      !devices.isEmpty else {
                    self.errorMessage = "No device connected via USB. Please connect your iPhone to the PC."
                    return
                }
                
                // Take the first device
                let deviceData = devices[0]
                if let udid = deviceData["udid"] as? String {
                    self.fetchedDevice = DeviceInfo(
                        udid: udid,
                        name: deviceData["name"] as? String ?? "Unknown Device",
                        trusted: deviceData["trusted"] as? Bool ?? false
                    )
                } else {
                    self.errorMessage = "Invalid response from server"
                }
            }
        }.resume()
    }
}

#Preview {
    OnboardingView(
        isOnboardingComplete: .constant(false),
        storedUDID: .constant("")
    )
}
