import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isOnboardingComplete: Bool
    var onReset: (() -> Void)?
    
    @State private var showingResetConfirmation = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            List {
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
        // Clear all AppStorage values
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.isOnboardingComplete)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.savedManualIPs)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.lastSelectedPC)
        
        // Notify parent to reset any in-memory state
        onReset?()
        
        // Update binding to trigger UI change
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOnboardingComplete = false
        }
        
        dismiss()
    }
}

#Preview {
    SettingsView(isOnboardingComplete: .constant(true))
}
