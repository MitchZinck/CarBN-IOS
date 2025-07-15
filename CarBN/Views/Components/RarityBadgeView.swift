import SwiftUI

struct RarityBadgeView: View {
    let rarity: Int
    
    private func rarityText() -> String {
        switch rarity {
        case 1: return "rarity.common".localized
        case 2: return "rarity.uncommon".localized
        case 3: return "rarity.rare".localized
        case 4: return "rarity.epic".localized
        case 5: return "rarity.legendary".localized
        default: return "rarity.common".localized
        }
    }
    
    private func rarityColor() -> Color {
        switch rarity {
        case 1: return Color(red: 176/255, green: 176/255, blue: 176/255) // Light Gray
        case 2: return Color(red: 0/255, green: 230/255, blue: 118/255)  // Neon Green
        case 3: return Color(red: 41/255, green: 121/255, blue: 255/255) // Bright Blue
        case 4: return Color(red: 213/255, green: 0/255, blue: 249/255)  // Vivid Purple
        case 5: return Color(red: 255/255, green: 196/255, blue: 0/255)  // Shiny Gold
        default: return Color.gray
        }
    }
    
    var body: some View {
        Text(rarityText())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(rarityColor())
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .padding(0)
    }
}