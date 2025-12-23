import SwiftUI

struct USBTroubleshootView: View {
    let pcName: String
    let message: String?
    let isFromSettings: Bool
    let onClose: () -> Void
    
    @State private var animatePulse = false
    @State private var rotate = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.18), Color.indigo.opacity(0.38)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                header
                animatedBadge
                stepList
                Spacer()
                primaryButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("USB Troubleshooting")
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
            if let message = message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect to \(pcName.isEmpty ? "your PC" : pcName) with the tips below.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var animatedBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 210, height: 210)
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: animatePulse ? 240 : 200, height: animatePulse ? 240 : 200)
                .opacity(animatePulse ? 0.35 : 0.6)
            Circle()
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(rotate ? 360 : 0))
            Image(systemName: "cable.connector")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 8)
        }
        .padding(.top, 12)
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
    
    private var stepList: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepRow(number: 1, title: "Use the USB cable", detail: "Connect your iPhone directly to \(pcName) using a reliable cable.")
            stepRow(number: 2, title: "Tap Trust", detail: "When prompted on your iPhone, tap Trust and enter your passcode.")
            stepRow(number: 3, title: "Keep the app open", detail: "Stay on this screen while we finalize the pairing.")
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.8), in: Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var primaryButton: some View {
        Button(action: onClose) {
            Text(isFromSettings ? "Close" : "Back to Pairing")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .controlSize(.regular)
        .padding(.top, 8)
    }
    
}

#Preview {
    USBTroubleshootView(pcName: "MacBook Pro", message: "We need a USB connection to finish pairing.") {}
}
