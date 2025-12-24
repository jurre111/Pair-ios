import SwiftUI

struct SideStoreUploadView: View {
    let isWorking: Bool
    let status: String?
    let error: String?
    var onClose: () -> Void

    @State private var pulse = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.25), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.08 : 0.94)
                        .opacity(pulse ? 1 : 0.6)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotation)

                    VStack(spacing: 10) {
                        Image(systemName: isWorking ? "arrow.down.circle.fill" : (error == nil ? "checkmark.circle.fill" : "xmark.octagon.fill"))
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(error == nil ? .white : .red)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 6)
                        Text("SideStore")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(spacing: 10) {
                    Text(isWorking ? "Uploading to SideStore…" : (error == nil ? "Uploaded" : "Upload Failed"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)

                    if let status, !isWorking, error == nil {
                        Text(status)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    if let error {
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 4)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Text(isWorking ? "Cancel" : "Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBlueButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .disabled(isWorking) // avoid cancel mid-upload to keep flow simple
            }
            .padding()
        }
        .onAppear {
            pulse = true
            rotation = 360
        }
    }
}

#Preview {
    SideStoreUploadView(isWorking: true, status: nil, error: nil, onClose: {})
}
