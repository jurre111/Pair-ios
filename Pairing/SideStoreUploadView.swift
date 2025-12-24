import UIKit
import SwiftUI

struct SideStoreUploadView: View {
    let isWorking: Bool
    let status: String?
    let error: String?
    var onClose: () -> Void

    @State private var ringProgress: CGFloat = 0.2
    @State private var showCheck = false
    @State private var markScale: CGFloat = 1.0
    @State private var progressDirectionForward = true

    private var isError: Bool { error != nil }
    private var isSuccess: Bool { !isWorking && error == nil }

    var body: some View {
        ZStack {
            CalmBackdrop()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                SimpleBadge(
                    isWorking: isWorking,
                    isError: isError,
                    progress: ringProgress,
                    showCheck: showCheck,
                    markScale: markScale
                )
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
        .onAppear { updateVisualState() }
        .onChange(of: isWorking) { _ in updateVisualState() }
        .onChange(of: error) { _ in updateVisualState() }
    }

    private func updateVisualState() {
        if isWorking {
            showCheck = false
            markScale = 1.0
            ringProgress = progressDirectionForward ? 0.85 : 0.2
            progressDirectionForward.toggle()
        } else if isSuccess {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                ringProgress = 1.0
                showCheck = true
                markScale = 1.08
            }
        } else if isError {
            withAnimation(.easeOut(duration: 0.35)) {
                ringProgress = 0.35
                showCheck = false
                markScale = 1.0
            }
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
    let isError: Bool
    let progress: CGFloat
    let showCheck: Bool
    let markScale: CGFloat

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .foregroundStyle(ringColor)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(isWorking ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .easeOut(duration: 0.35), value: progress)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 170, height: 170)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .overlay {
                        ZStack {
                            if showCheck {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .scaleEffect(markScale)
                                    .transition(.scale)
                            } else {
                                SideStoreMark()
                                    .frame(width: 96, height: 96)
                            }
                        }
                    }
            }

            Text(isWorking ? "Configuring" : (isError ? "Failed" : "Ready"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isError ? .red : .secondary)
        }
    }

    private var ringColor: Color {
        if isError { return .red }
        return isWorking ? .blue : .green
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
