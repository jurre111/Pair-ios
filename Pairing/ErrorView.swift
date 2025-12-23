import SwiftUI

struct ErrorView: View {
    let error: PairingError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.red)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .scaleEffect(showContent ? 1.0 : 0.8)
            
            // Error text
            VStack(spacing: 12) {
                Text("Something Went Wrong")
                    .font(.title2.weight(.semibold))
                
                Text(error.errorDescription ?? "Unknown error")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    onRetry()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    onDismiss()
                } label: {
                    Text("Go Back")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 30)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    ErrorView(
        error: .usbTimeout,
        onRetry: {},
        onDismiss: {}
    )
}
