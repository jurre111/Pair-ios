import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var storedUDID: String
    @Binding var isOnboardingComplete: Bool
    
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Identifier")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Device")
                } footer: {
                    Text("This identifier is used for pairing. It's unique to this app on your device.")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset App", systemImage: "trash")
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Resetting will restart the onboarding process.")
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
                "Reset App?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        storedUDID = ""
                        isOnboardingComplete = false
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restart the app and show the welcome screen again.")
            }
        }
    }
}

#Preview {
    SettingsView(
        storedUDID: .constant(""),
        isOnboardingComplete: .constant(true)
    )
}
