import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PairingViewModel()
    @State private var selectedPC: String?
    @State private var manualIP: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("iOS Pairing Client")
                    .font(.title)
                
                Text(viewModel.status)
                    .multilineTextAlignment(.center)
                    .padding()
                
                if !viewModel.serviceBrowser.discoveredPCs.isEmpty {
                    Text("Discovered PCs:")
                        .font(.headline)
                    
                    List(viewModel.serviceBrowser.discoveredPCs.keys.sorted(), id: \.self) { name in
                        Button(action: {
                            selectedPC = name
                        }) {
                            HStack {
                                Text(name)
                                Spacer()
                                if selectedPC == name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .frame(height: 150)
                    
                    if selectedPC != nil {
                        Button("Request Pairing from \(selectedPC!)") {
                            viewModel.requestPairing(for: selectedPC!)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.pairingFileSaved)
                    }
                } else {
                    Text("No PCs found. Make sure PC is running the server on the same network.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if viewModel.pairingFileSaved {
                    Text("Pairing file saved successfully!")
                        .foregroundColor(.green)
                }
                
                // Manual IP entry
                TextField("Enter PC IP (e.g. 192.168.1.100)", text: $manualIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal)
                
                Button("Add Manual PC") {
                    if !manualIP.isEmpty {
                        let url = URL(string: "http://\(manualIP):5000")!
                        viewModel.serviceBrowser.discoveredPCs["Manual PC (\(manualIP))"] = url
                        viewModel.objectWillChange.send()
                    }
                }
                .buttonStyle(.bordered)
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
}

#Preview {
    ContentView()
}
