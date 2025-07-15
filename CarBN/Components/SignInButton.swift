import SwiftUI

struct SignInButton: View {
    let text: String
    let icon: String
    let isSystemImage: Bool
    let action: () -> Void
    
    init(text: String, icon: String, isSystemImage: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.isSystemImage = isSystemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isSystemImage {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
                } else {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
                }
                
                Text(text)
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white)
            .cornerRadius(12)
        }
        .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
    }
}
