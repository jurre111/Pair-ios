import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    @AppStorage("storedUDID") private var storedUDID = ""
    
    @StateObject private var viewModel = PairingViewModel()
    @State private var selectedPC: String?
    @State private var manualIP: String = ""
    @State private var showingShareSheet = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if isOnboardingComplete {
                mainContent
            } else {
                OnboardingView(
                    isOnboardingComplete: $isOnboardingComplete,
                    storedUDID: $storedUDID
                )
            }
        }
        .onChange(of: storedUDID) { newValue in
            viewModel.storedUDID = newValue
        }
        .onAppear {
            viewModel.storedUDID = storedUDID
        }
    }
    
    private var mainContent: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        statusHeader
                        discoveredSection
                        
                        if viewModel.showDebugLogs {
                            debugLogsSection
                        }
                        
                        manualEntrySection
                    }
                    .padding()
                }
            }
            .navigationTitle("Pairing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .alert("Connect USB", isPresented: $viewModel.showUSBAlert) {
                Button("OK") {}
            } message: {
                Text("Please plug in your iPhone to the PC via USB cable to finish pairing.")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = viewModel.pairingFileURL {
                    ShareSheet(activityItems: [fileURL])
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    storedUDID: $storedUDID,
                    isOnboardingComplete: $isOnboardingComplete
                )
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Text("iOS Pairing Client")
                .font(.largeTitle.weight(.bold))

            Text(viewModel.status)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if viewModel.pairingFileSaved {
                Label("Pairing file saved", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.footnote)
            }

            if viewModel.pairingFileURL != nil {
                Button("Share pairing file…") {
                    showingShareSheet = true
                }
                .font(.footnote)
            }

            Button(viewModel.showDebugLogs ? "Hide discovery logs" : "Show discovery logs") {
                viewModel.showDebugLogs.toggle()
            }
            .font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discovered PCs")
                    .font(.headline)
                Spacer()
                Button("Rescan") {
                    viewModel.refreshDiscovery()
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
                if viewModel.isSearchingForServices && viewModel.discoveredPCs.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if viewModel.discoveredPCs.isEmpty {
                VStack(spacing: 6) {
                    Text(viewModel.isSearchingForServices ? "Still scanning your network..." : "No PCs found yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Ensure the PC companion app is running on the same Wi-Fi and advertising the pairing service.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Note: Some networks block device discovery. Use Manual PC below if discovery doesn't work.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    
                    if !viewModel.isSearchingForServices && !viewModel.serviceBrowser.debugLogs.isEmpty {
                        Button("Show Discovery Logs") {
                            viewModel.showDebugLogs = true
                        }
                        .font(.caption)
                        .padding(.top, 8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.discoveredPCs.keys.sorted(), id: \.self) { name in
                        Button {
                            selectedPC = name
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(viewModel.discoveredPCs[name]?.host ?? "Pairing service")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedPC == name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPC == name ? Color.blue.opacity(0.15) : Color(.systemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: {
                if let selected = selectedPC {
                    viewModel.requestPairing(for: selected)
                }
            }) {
                Text("Pair with Selected PC")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPC == nil || viewModel.pairingFileSaved)
            .opacity(selectedPC == nil ? 0.5 : 1)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual PC")
                .font(.headline)

            Text("Paste the local IP address of your PC and an optional port (default 5000). Example: 192.168.2.10:5000")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                TextField("192.168.1.100 or 192.168.1.100:5000", text: $manualIP)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)

                Button("Add") {
                    if let key = viewModel.addManualPC(ip: manualIP) {
                        selectedPC = key
                        manualIP = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    
    private var debugLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discovery Logs")
                    .font(.headline)
                Spacer()
                Button("Hide") {
                    viewModel.showDebugLogs = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            if viewModel.serviceBrowser.debugLogs.isEmpty {
                Text("No logs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.serviceBrowser.debugLogs, id: \.self) { log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    ContentView()
}

// Simple share sheet helper to export the pairing file
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
