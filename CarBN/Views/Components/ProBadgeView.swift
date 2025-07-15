import SwiftUI

struct ProBadgeView: View {
    var compact: Bool = false
    
    var body: some View {
        Text("PRO")
            .font(compact ? .caption.bold() : .caption2.bold())
            .padding(.horizontal, compact ? 6 : 4)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    ProBadgeView()
        .padding()
        .background(.black)
}