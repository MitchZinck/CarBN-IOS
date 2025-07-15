import SwiftUI

struct PulsingImageView: View {
    let image: UIImage
    let isAnimating: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0.0
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(glowOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor)
                    .opacity(glowOpacity * 0.2)
            )
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.05
                        glowOpacity = 0.8
                    }
                } else {
                    withAnimation {
                        pulseScale = 1.0
                        glowOpacity = 0.0
                    }
                }
            }
    }
}
