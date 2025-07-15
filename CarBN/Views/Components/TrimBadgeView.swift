import SwiftUI

struct TrimBadgeView: View {
    let trim: String
    
    var body: some View {
        Text(trim)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .padding(0)
    }
}
