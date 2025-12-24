import UIKit
import SwiftUI

struct SideStoreUploadView: View {
    let isWorking: Bool
    let status: String?
    let error: String?
    var onClose: () -> Void

    var body: some View {
        ZStack {
            AnimatedBackdrop()
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                RadiantOrbit(isWorking: isWorking)
                    .frame(width: 360, height: 360)

                VStack(spacing: 10) {
                    Text(isWorking ? "Uploading to SideStore" : (error == nil ? "Uploaded to SideStore" : "Upload Failed"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .transition(.opacity)

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

                Spacer(minLength: 12)

                Button {
                    onClose()
                } label: {
                    Text(isWorking ? "Cancel" : "Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBlueButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .disabled(isWorking)
                .opacity(isWorking ? 0.75 : 1)
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

private struct AnimatedBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.blue.opacity(0.18))
                .blur(radius: 90)
                .frame(width: 420, height: 420)
                .offset(x: -180, y: -260)

            Circle()
                .fill(Color.purple.opacity(0.2))
                .blur(radius: 80)
                .frame(width: 420, height: 420)
                .offset(x: 200, y: 220)
        }
    }
}

private struct RadiantOrbit: View {
    let isWorking: Bool
    private let dotCount = 48
    private let radius: CGFloat = 150

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let rotation = Angle.degrees((time.truncatingRemainder(dividingBy: 12)) * 35)

                ZStack {
                    ForEach(0..<dotCount, id: \.self) { index in
                        let progress = Double(index) / Double(dotCount)
                        let angle = Angle.degrees(progress * 360)
                        let size = 7 + sin(time * 1.6 + progress * .pi * 2) * 1.4
                        Circle()
                            .fill(Color(hue: progress, saturation: 0.82, brightness: 0.98))
                            .frame(width: size, height: size)
                            .offset(
                                x: cos(angle.radians) * radius,
                                y: sin(angle.radians) * radius
                            )
                    }
                }
                .rotationEffect(rotation)
            }
            .blur(radius: 0.15)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.98, green: 0.63, blue: 0.15),
                            Color(red: 0.98, green: 0.17, blue: 0.34),
                            Color(red: 0.35, green: 0.28, blue: 0.96),
                            Color(red: 0.14, green: 0.66, blue: 0.98),
                            Color(red: 0.20, green: 0.78, blue: 0.45),
                            Color(red: 0.98, green: 0.63, blue: 0.15)
                        ]),
                        center: .center
                    ),
                    lineWidth: 14
                )
                .frame(width: 240, height: 240)
                .opacity(0.7)
                .shadow(color: Color.blue.opacity(0.25), radius: 16, x: 0, y: 8)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 170, height: 170)
                .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 6)
                .overlay {
                    VStack(spacing: 14) {
                        SideStoreMark()
                            .frame(width: 96, height: 96)
                            .padding(12)
                        Text(isWorking ? "Configuring" : "Ready")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
        }
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
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
