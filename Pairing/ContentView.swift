import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PairingViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("iOS Pairing Client")
                .font(.title)
            
            Text(viewModel.status)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Request Pairing") {
                viewModel.requestPairing()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.pairingFileSaved)
            
            if viewModel.pairingFileSaved {
                Text("Pairing file saved successfully!")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .alert("Connect USB", isPresented: $viewModel.showUSBAlert) {
            Button("OK") {
                // User acknowledges, perhaps retry later
            }
        } message: {
            Text("Please connect your iPhone to the PC via USB cable to complete the pairing process.")
        }
    }
}

#Preview {
    ContentView()
}
