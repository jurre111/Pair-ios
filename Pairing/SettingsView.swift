import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isOnboardingComplete: Bool
    
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
                }
                
                // Actions Section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset App", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("This will show the welcome screen again.")
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
                    Text("Pairing helps you create pairing files for iOS devices to connect with a PC.")
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
                Button("Reset", role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isOnboardingComplete = false
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will show the welcome screen again and clear any saved settings.")
            }
        }
    }
}

#Preview {
    SettingsView(isOnboardingComplete: .constant(true))
}
