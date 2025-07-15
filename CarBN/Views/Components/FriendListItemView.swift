import SwiftUI

struct FriendListItemView: View {
    let friend: Friend
    var showProBadge: Bool = false
    
    var body: some View {
        HStack {
            if let profilePicture = friend.profilePicture {
                CachedAsyncImage(url: URL(string: "\(APIConstants.baseURL)/\(profilePicture)")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        fallbackUserImage
                    }
                }
            } else {
                fallbackUserImage
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.displayName.isEmpty == false ? friend.displayName : "Unknown")
                    .foregroundStyle(.white)
                        .font(.headline)                
                    Text("#\(friend.id)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    Spacer()
                    Text("Click to trade")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                if showProBadge {
                    ProBadgeView()
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var fallbackUserImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(.gray)
            }
    }
}
