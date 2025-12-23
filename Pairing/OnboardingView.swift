import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var showContent = false
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                
                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.blue)
                    .scaleEffect(iconScale)
            }
            .opacity(showContent ? 1 : 0)
            
            Text("Pairing")
                .font(.system(size: 38, weight: .bold))
                .padding(.top, 24)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
            
            Text("Get your pairing file in seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
            
            Spacer()
            
            // Features list
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Find Your PC",
                    description: "Automatically discovers nearby pairing servers"
                )
                
                FeatureRow(
                    icon: "cable.connector",
                    title: "Connect via USB",
                    description: "Plug in your iPhone and tap Trust when prompted"
                )
                
                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Share the File",
                    description: "Export your pairing file to use with other apps"
                )
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            
            Spacer()
            
            // Get Started button
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isOnboardingComplete = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                iconScale = 1.0
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
