import SwiftUI

struct FriendSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = FriendsViewModel()
    @State private var showingTradeView = false
    @State private var selectedFriend: Friend?
    @State private var friendCars: [Car] = []
    @State private var isLoadingFriendCars = false
    @State private var friendSubscriptionStatus: [Int: Bool] = [:] // Cache friend subscription status
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            AppConstants.backgroundColor
                .ignoresSafeArea()
            
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if viewModel.friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("Add some friends first!")
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    friendsList
                }
            }
        }
        .navigationTitle("Select Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .task {
            await viewModel.loadFriends(userId: UserManager.shared.currentUser!.id)
            await viewModel.loadCurrentUserCars()
            
            // Batch check subscription status for all friends
            let statuses = await SubscriptionService.shared.batchCheckSubscriptionStatus(
                userIds: viewModel.friends.map { $0.id }
            )
            friendSubscriptionStatus = statuses
        }
        .sheet(isPresented: $showingTradeView) {
            if let friend = selectedFriend {
                TradeView(
                    friendId: friend.id,
                    friendName: friend.displayName,
                    friendCars: friendCars
                )
            }
        }
        .alert("Can't Trade", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    FriendListItemView(
                        friend: friend,
                        showProBadge: friendSubscriptionStatus[friend.id] == true
                    )
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleFriendSelection(friend)
                    }
                    .overlay {
                        if isLoadingFriendCars && selectedFriend?.id == friend.id {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .opacity(canTradeWithFriend(friend) ? 1.0 : 0.5)
                    .overlay {
                        if !canTradeWithFriend(friend) {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func canTradeWithFriend(_ friend: Friend) -> Bool {
        guard let subscription = appState.subscription, subscription.isActive else {
            return false
        }
        return friendSubscriptionStatus[friend.id] == true
    }
    
    private func handleFriendSelection(_ friend: Friend) {
        guard let subscription = appState.subscription else { return }
        
        if !subscription.isActive {
            alertMessage = "You need an active subscription to trade cars."
            showingAlert = true
            return
        }
        
        if friendSubscriptionStatus[friend.id] != true {
            alertMessage = "\(friend.displayName) doesn't have an active subscription required for trading."
            showingAlert = true
            return
        }
        
        Task {
            isLoadingFriendCars = true
            selectedFriend = friend
            do {
                let friendCarsFetched: [Car] = try await CarService.shared.fetchUsersCars(userId: friend.id)
                friendCars = friendCarsFetched
                showingTradeView = true
            } catch {
                print("Error fetching cars for friend: \(friend.id), error: \(error)")
            }
            isLoadingFriendCars = false
        }
    }
}
