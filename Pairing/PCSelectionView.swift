import SwiftUI

struct PCSelectionView: View {
    @ObservedObject var viewModel: PairingViewModel
    @State private var manualIP = ""
    @State private var pulseOpacity = false
    @FocusState private var isManualIPFocused: Bool
    @State private var shimmer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                pcListSection
                manualEntrySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.9), Color.indigo.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: shimmer ? 180 : 140, height: shimmer ? 180 : 140)
                            .offset(x: -80, y: -50)
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: shimmer ? 220 : 160, height: shimmer ? 220 : 160)
                            .offset(x: 90, y: 60)
                    }
                )
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: shimmer)
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Live")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 6) {
                    Text("Select Your PC")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Choose a PC running the pairing server")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                HStack(spacing: 12) {
                    statusPill(icon: "antenna.radiowaves.left.and.right", text: viewModel.isSearching ? "Scanning" : "Ready")
                    statusPill(icon: "bolt.fill", text: viewModel.canConnect ? "Good to connect" : "Select a PC")
                }
            }
            .padding(20)
        }
        .onAppear { shimmer = true }
    }

    private func statusPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.16), in: Capsule())
            .foregroundStyle(.white)
    }
    
    // MARK: - PC List
    
    private var pcListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available PCs")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        viewModel.refreshDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if viewModel.discoveredPCs.isEmpty {
                emptyStateCard
            } else {
                pcListCards
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isSearching ? "wifi" : "wifi.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
                .opacity(viewModel.isSearching ? (pulseOpacity ? 0.4 : 1.0) : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseOpacity)
            
            Text(viewModel.isSearching ? "Searching..." : "No PCs Found")
                .font(.headline)
            
            Text("Make sure the pairing server is running on your PC and both devices are on the same network.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            if viewModel.isSearching {
                pulseOpacity = true
            }
        }
        .onChange(of: viewModel.isSearching) { isSearching in
            pulseOpacity = isSearching
        }
    }
    
    private var pcListCards: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.discoveredPCs) { pc in
                PCRowView(
                    pc: pc,
                    isSelected: viewModel.selectedPCId == pc.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectPC(pc)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onDelete: pc.isManual ? {
                        withAnimation {
                            viewModel.removeManualPC(id: pc.id)
                        }
                    } : nil
                )
            }
        }
    }
    
    // MARK: - Manual Entry
    
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manual Address")
                    .font(.headline)
                Text("Enter IP or hostname to add it to your list and select it immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .foregroundStyle(.secondary)
                    TextField("192.168.1.100", text: $manualIP)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isManualIPFocused)
                }
                .padding(12)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )

                Button {
                    if viewModel.addManualPC(ip: manualIP) {
                        manualIP = ""
                        isManualIPFocused = false
                    }
                } label: {
                    Text("Save & Select")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.blue)
                .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - PC Row View

struct PCRowView: View {
    let pc: DiscoveredPC
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // PC info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pc.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        if pc.isManual {
                            Text("Manual")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                    
                    Text(pc.displayAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Delete button for manual entries
                if let onDelete = onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PCSelectionView(viewModel: PairingViewModel())
}
