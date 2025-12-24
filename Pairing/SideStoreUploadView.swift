import UIKit
import SwiftUI

struct SideStoreUploadView: View {
    let isWorking: Bool
    let status: String?
    let error: String?
    var onClose: () -> Void

    var body: some View {
        ZStack {
            CalmBackdrop()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                SimpleBadge(isWorking: isWorking)
                    .frame(width: 240, height: 240)

                VStack(spacing: 10) {
                    Text(isWorking ? "Uploading to SideStore" : (error == nil ? "Uploaded to SideStore" : "Upload Failed"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let status, !isWorking, error == nil {
                        Text(status)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }

                    if let error {
                        Text(error)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer(minLength: 24)

                Button {
                    onClose()
                } label: {
                    Text(isWorking ? "Cancel" : "Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBlueButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .disabled(isWorking)
                .opacity(isWorking ? 0.8 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    SideStoreUploadView(isWorking: true, status: nil, error: nil, onClose: {})
}

// MARK: - Components

private struct CalmBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.black.opacity(0.05), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }
}

private struct SimpleBadge: View {
    let isWorking: Bool
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 170, height: 170)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .overlay {
                        SideStoreMark()
                            .frame(width: 96, height: 96)
                    }
            }

            Text(isWorking ? "Configuring" : "Ready")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .onAppear { pulse = true }
    }
}

private struct SideStoreMark: View {
    var body: some View {
        if UIImage(named: "SideStoreLogo") != nil {
            Image("SideStoreLogo")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemGray4))
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
