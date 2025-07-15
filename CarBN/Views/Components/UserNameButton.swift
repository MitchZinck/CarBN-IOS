import SwiftUI

struct UserNameButton: View {
    let name: String?
    let userId: Int
    let currentUserId: Int?
    @State private var showUserProfile = false
    
    var body: some View {
        if userId == currentUserId {
            Text("You")
                .foregroundStyle(.white)
        } else {
            Button {
                showUserProfile = true
            } label: {
                Text(name ?? "Unknown")
                    .foregroundStyle(.white)
            }
            .sheet(isPresented: $showUserProfile) {
                FriendProfileView(userId: userId)
            }
        }
    }
}
