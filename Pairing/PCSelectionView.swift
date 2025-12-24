import SwiftUI

struct PCSelectionView: View {
    @ObservedObject var viewModel: PairingViewModel
    @State private var manualIP = ""
    @State private var pulseOpacity = false
    @FocusState private var isManualIPFocused: Bool
    
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
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Select Your PC")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Make sure the Pairing Buddy server is running and you're on the same Wi‑Fi.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            )
            .frame(maxWidth: .infinity, minHeight: 150)
    }
    
    // MARK: - PC List
    
    private var pcListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available PCs")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                Button {
                    viewModel.refreshDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
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
            if viewModel.isSearching {
                Image(systemName: "wifi")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
                    .scaleEffect(pulseOpacity ? 1.05 : 0.9)
                    .opacity(pulseOpacity ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulseOpacity)
                    .padding(.top, 4)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.red)
            }
            
            Text(viewModel.isSearching ? "Searching..." : "No PCs Found")
                .font(.headline)
            
            Text("Make sure the pairing server is running and both devices share the same network. Or add a host manually below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .onAppear { pulseOpacity = viewModel.isSearching }
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
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBlueButtonStyle())
                .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
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
