import SwiftUI

struct SuccessView: View {
    let fileURL: URL
    let onShare: () -> Void
    let onDone: () -> Void
    var sidestoreStatus: String? = nil
    var sidestoreError: String? = nil
    var sidestoreWorking: Bool = false
    var sidestoreDisabled: Bool = false
    var onInstallSideStore: (() -> Void)? = nil
    
    @State private var showCheckmark = false
    @State private var showContent = false
    @State private var checkmarkScale: CGFloat = 0.3
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
                
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }
            
            // Success text
            VStack(spacing: 12) {
                Text("Paired Successfully!")
                    .font(.title.weight(.semibold))
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                
                Text("Your pairing file is ready to share")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    onShare()
                } label: {
                    Label("Share Pairing File", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                if let onInstallSideStore {
                    Button {
                        onInstallSideStore()
                    } label: {
                        HStack {
                            if sidestoreWorking {
                                ProgressView().scaleEffect(0.8)
                            }
                            Label("Send to SideStore", systemImage: "square.and.arrow.down")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .disabled(sidestoreWorking || sidestoreDisabled)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    if let sidestoreStatus {
                        Text(sidestoreStatus)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    if let sidestoreError {
                        Text(sidestoreError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
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
            animateIn()
        }
    }
    
    private func animateIn() {
        // Checkmark pop animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            showCheckmark = true
            checkmarkScale = 1.0
        }
        
        // Content fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            showContent = true
        }
    }
}

#Preview {
    SuccessView(
        fileURL: URL(fileURLWithPath: "/test.mobiledevicepairing"),
        onShare: {},
        onDone: {}
    )
}
