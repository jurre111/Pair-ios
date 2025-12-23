import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var viewModel: PairingViewModel
    var onReset: (() -> Void)?
    var onShowUSBHelp: (() -> Void)? = nil

    @State private var showingResetConfirmation = false
    @State private var sidestoreStatus: String?
    @State private var sidestoreError: String?
    @State private var sidestoreWorking = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
                // Saved PCs Section
                Section {
                    let saved = viewModel.savedPCs
                    if saved.isEmpty {
                        Label("No saved PCs yet", systemImage: "tray")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(saved) { pc in
                            let isAvailable = viewModel.isSavedPCAvailable(pc)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pc.name)
                                        .font(.body.weight(.medium))
                                    Text(pc.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if pc.isManual {
                                    Text("Manual")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color(.systemGray5), in: Capsule())
                                }
                                Text(isAvailable ? "Available" : "Offline")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background((isAvailable ? Color.green.opacity(0.15) : Color.gray.opacity(0.12)), in: Capsule())
                                    .foregroundStyle(isAvailable ? Color.green : Color.secondary)
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.removeSavedPC(id: pc.id)
                                        if pc.isManual {
                                            viewModel.removeManualPC(id: pc.id)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                } header: {
                    Text("Saved PCs")
                } footer: {
                    Text("Saved PCs stay listed here; offline ones reappear when available.")
                }

                // Device Info Section
                Section {
                    HStack {
                        Label("Device", systemImage: "iphone")
                        Spacer()
                        Text(UIDevice.current.name)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("iOS Version", systemImage: "gear")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Device Information")
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                            Text("Reset App")
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Clears all app data including saved PCs, settings, and shows the welcome screen.")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Pairing helps you create pairing files for iOS devices.")
                }

                // Support Section
                Section {
                    Button {
                        onShowUSBHelp?()
                    } label: {
                        Label("USB Troubleshooting", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.plain)
                    Label("Need help? Contact your admin.", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Reset App?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    resetApp()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all saved data and return the app to its initial state. This cannot be undone.")
            }
        }
    }

    private func resetApp() {
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.isOnboardingComplete)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.savedManualIPs)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.lastSelectedPC)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.savedPCs)

        onReset?()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOnboardingComplete = false
        }

        dismiss()
    }
}

#Preview {
    SettingsView(isOnboardingComplete: .constant(true), viewModel: PairingViewModel())
}
