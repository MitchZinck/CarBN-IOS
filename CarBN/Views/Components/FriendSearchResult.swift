import SwiftUI

@MainActor
struct FriendSearchResult: View {
    let user: User
    let onAdd: () -> Void
    @State private var currentUserId: Int?
    
    var body: some View {
        HStack {
            if let profilePicture = user.profilePicture {
                CachedAsyncImage(url: URL(string: "\(APIConstants.baseURL)/\(profilePicture)")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        fallbackUserImage
                    }
                }
                .frame(width: 40, height: 40) // Add fixed frame to container
            } else {
                fallbackUserImage
            }
            
            VStack(alignment: .leading) {
                HStack {
                    UserNameButton(
                        name: user.displayName,
                        userId: user.id,
                        currentUserId: currentUserId
                    )
                    Text("#\(user.id)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                Text(String(format: "friends.friend_count".localized, user.friendCount))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                onAdd()
            } label: {
                Text("friends.add".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(AppConstants.backgroundColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            // Get currentUserId on the main actor
            currentUserId = UserManager.shared.currentUser?.id
        }
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
