import SwiftUI

struct ConnectionProgressView: View {
    let pcName: String
    let isAwaitingUSB: Bool
    let usbMessage: String?
    let onCancel: () -> Void
    let onShowUSBHelp: () -> Void
    
    @State private var showUSBInstructions = false
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .opacity(pulseAnimation ? 0.5 : 1.0)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: isAwaitingUSB ? "cable.connector" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(isAwaitingUSB ? .default : .linear(duration: 2).repeatForever(autoreverses: false), value: rotationAngle)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                if !isAwaitingUSB {
                    rotationAngle = 360
                }
            }
            .onChange(of: isAwaitingUSB) { awaiting in
                rotationAngle = awaiting ? 0 : 360
            }
            
            // Status text
            VStack(spacing: 12) {
                Text(isAwaitingUSB ? "USB Connection Required" : "Connecting...")
                    .font(.title2.weight(.semibold))
                
                Text(isAwaitingUSB ? "Connect your iPhone to \(pcName) via USB" : "Contacting \(pcName)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // USB Instructions
            if isAwaitingUSB {
                usbInstructionsCard
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
            
            // Cancel button
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)

            if isAwaitingUSB {
                Button {
                    onShowUSBHelp()
                } label: {
                    Text("Need USB help?")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBlueButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)
            .padding(.bottom, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isAwaitingUSB)
    }
    
    private var usbInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionRow(number: 1, text: "Connect iPhone to PC with USB cable")
            instructionRow(number: 2, text: "Tap \"Trust\" when prompted on your iPhone")
            instructionRow(number: 3, text: "Enter your passcode if asked")
            
            // Polling indicator
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Waiting for connection...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue, in: Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Connecting") {
    ConnectionProgressView(
        pcName: "MacBook-Pro",
        isAwaitingUSB: false,
        usbMessage: nil,
        onCancel: {},
        onShowUSBHelp: {}
    )
}

#Preview("USB Required") {
    ConnectionProgressView(
        pcName: "MacBook-Pro",
        isAwaitingUSB: true,
        usbMessage: "Please connect via USB",
        onCancel: {},
        onShowUSBHelp: {}
    )
}
