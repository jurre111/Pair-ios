import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @Binding var storedUDID: String
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            TitleView()
            
            Spacer()
            
            InformationContainerView()
            
            Spacer()
            
            Button(action: {
                isOnboardingComplete = true
            }) {
                Text("Continue")
                    .customButton()
            }
            .padding(.bottom, 50)
        }
    }
}

struct TitleView: View {
    var body: some View {
        VStack {
            Image(systemName: "cable.connector.horizontal")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
            
            Text("Pairing")
                .customTitleText()
        }
    }
}

struct InformationContainerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InformationDetailView(title: "USB Connection", subTitle: "Connect your iPhone to PC via USB cable", imageName: "cable.connector")
            
            InformationDetailView(title: "Trust Device", subTitle: "Tap 'Trust' when prompted on your iPhone", imageName: "hand.tap")
            
            InformationDetailView(title: "Get Pairing File", subTitle: "Receive and share your device pairing file", imageName: "doc.text")
        }
        .padding(.horizontal, 40)
    }
}

struct InformationDetailView: View {
    var title: String
    var subTitle: String
    var imageName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func customTitleText() -> some View {
        self
            .font(.system(size: 42, weight: .bold))
            .foregroundColor(.primary)
    }
    
    func customButton() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(Color.blue)
            .cornerRadius(15)
            .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingView(
        isOnboardingComplete: .constant(false),
        storedUDID: .constant("")
    )
}
