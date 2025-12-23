import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage(Constants.StorageKeys.isOnboardingComplete) private var isOnboardingComplete = false
    
    @StateObject private var viewModel = PairingViewModel()
    @State private var showingShareSheet = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if isOnboardingComplete {
                mainContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isOnboardingComplete)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Content based on state
                stateBasedContent
            }
            .navigationTitle("Pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .selectPC = viewModel.state {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(isOnboardingComplete: $isOnboardingComplete)
            }
            .sheet(isPresented: $showingShareSheet) {
                if case .success(let fileURL) = viewModel.state {
                    ShareSheet(activityItems: [fileURL]) { completed in
                        if completed {
                            // Optionally reset after sharing
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSavedManualIPs()
        }
    }
    
    @ViewBuilder
    private var stateBasedContent: some View {
        switch viewModel.state {
        case .selectPC:
            VStack(spacing: 0) {
                PCSelectionView(viewModel: viewModel)
                
                // Connect button at bottom
                if viewModel.canConnect {
                    connectButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.canConnect)
            
        case .connecting(let pcName):
            ConnectionProgressView(
                pcName: pcName,
                isAwaitingUSB: false,
                usbMessage: nil,
                onCancel: { viewModel.cancel() }
            )
            .transition(.opacity)
            
        case .awaitingUSB(let pcName, let message):
            ConnectionProgressView(
                pcName: pcName,
                isAwaitingUSB: true,
                usbMessage: message,
                onCancel: { viewModel.cancel() }
            )
            .transition(.opacity)
            
        case .success(let fileURL):
            SuccessView(
                fileURL: fileURL,
                onShare: { showingShareSheet = true },
                onDone: { viewModel.reset() }
            )
            .transition(.opacity)
            
        case .error(let error):
            ErrorView(
                error: error,
                onRetry: {
                    viewModel.dismissError()
                    if viewModel.selectedPC != nil {
                        viewModel.connect()
                    }
                },
                onDismiss: { viewModel.dismissError() }
            )
            .transition(.opacity)
        }
    }
    
    private var connectButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                viewModel.connect()
            } label: {
                HStack {
                    Text("Connect to \(viewModel.selectedPC?.name ?? "PC")")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.regularMaterial)
        }
    }
}

#Preview {
    ContentView()
}
