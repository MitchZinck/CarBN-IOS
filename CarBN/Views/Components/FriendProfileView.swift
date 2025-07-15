import SwiftUI

enum CarSort {
    case rarity
    case name
    case dateCollected
}

struct FriendProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: FriendProfileViewModel?
    @State private var tradeViewModel: TradeViewModel
    @State private var sortOption: CarSort = .rarity
    @State private var showingTradeView = false
    @State private var hasSubscription = false
    @State private var showFriendsList = false
    private let userId: Int
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    
    init(userId: Int) {
        self.userId = userId
        self._tradeViewModel = State(initialValue: TradeViewModel(toUserId: userId))
        // Initialize viewModel in task to ensure MainActor context
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor
                    .ignoresSafeArea()
                
                if viewModel?.isLoading ?? true {
                    ProgressView()
                        .tint(.accentColor)
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            profileHeader
                            carCollectionSection
                        }
                        .padding()
                    }
                }
            }
            .background(AppConstants.backgroundColor)
            .alert("common.error".localized, isPresented: .constant((viewModel?.errorMessage != nil))) {
                Button("common.ok".localized) { viewModel?.errorMessage = nil }
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
            .navigationTitle("profile.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .navigationDestination(isPresented: $showFriendsList) {
                if let user = viewModel?.user {
                    FriendsView(isModal: true, userId: user.id, userName: user.displayName)
                }
            }
        }
        .background(AppConstants.backgroundColor)
        .task {
            // Initialize viewModel in MainActor context
            if viewModel == nil {
                viewModel = FriendProfileViewModel(userId: userId, appState: appState)
            }
            await viewModel?.loadData()
            // Check subscription status
            if let status = try? await SubscriptionService.shared.getUserSubscriptionStatus(userId: userId) {
                hasSubscription = status
            }
        }
        .onAppear {
            Task {
                await viewModel?.loadUser()
            }
        }
        .onChange(of: sortOption) { _, newValue in
            if let viewModel = viewModel {
                Task {
                    await viewModel.updateSortOption(newSort: newValue)
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            if let user = viewModel?.user,
               let profilePicture = user.profilePicture,
               let url = URL(string: "\(APIConstants.baseURL)/\(profilePicture)") {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 2)
                    case .failure, .empty:
                        fallbackProfileImage
                    @unknown default:
                        fallbackProfileImage
                    }
                }
            } else {
                fallbackProfileImage
            }
            
            HStack(spacing: 4) {
                UserNameButton(
                    name: viewModel?.user?.displayName,
                    userId: viewModel?.userId ?? 0,
                    currentUserId: UserManager.shared.currentUser?.id
                )
                Text("#\(viewModel?.userId ?? 0)")
                    .font(.title3)
                    .foregroundStyle(.gray)
                if hasSubscription {
                    ProBadgeView()
                }
            }
            .foregroundColor(.white)
            
            HStack(spacing: 30) {
                statView(number: "\(viewModel?.user?.carCount ?? 0)", label: "profile.stat.collected".localized)
                Button {
                    if viewModel?.user != nil {
                        showFriendsList = true
                    }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(viewModel?.user?.friendCount ?? 0)")
                                .font(.title3.bold())
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("profile.stat.friends".localized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                statView(number: "\(viewModel?.user?.carScore ?? 0)", label: "profile.stat.score".localized)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let viewModel = viewModel {
                if !viewModel.isCurrentUser {
                    if viewModel.isFriend {
                        // Only show trade button if both users have active subscriptions
                        if let subscription = appState.subscription, !subscription.isActive {
                            SubscriptionRequiredView(
                                title: "subscription.required.title".localized, 
                                message: "subscription.required.message".localized,
                                showSubscribeButton: true
                            )
                        } else if !hasSubscription {
                            SubscriptionRequiredView(
                                title: "subscription.required.title".localized,
                                message: "friend.no_subscription".localized,
                                icon: "person.fill.xmark",
                                showSubscribeButton: false
                            )
                        } else {
                            Button {
                                showingTradeView = true
                            } label: {
                                Label("profile.trade_cars".localized, systemImage: "arrow.left.arrow.right")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    } else {
                        Button {
                            if (!viewModel.friendRequestPending) {
                                Task {
                                    await viewModel.sendFriendRequest()
                                }
                            }
                        } label: {
                            Label(
                                viewModel.friendRequestPending ? "friends.requests.pending".localized : "friends.add".localized,
                                systemImage: viewModel.friendRequestPending ? "clock" : "person.badge.plus"
                            )
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(viewModel.friendRequestPending ? Color.gray : Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(viewModel.friendRequestPending)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .sheet(isPresented: $showingTradeView) {
            TradeView(
                friendId: userId,
                friendName: viewModel?.user?.displayName ?? "profile.default_user".localized,
                friendCars: viewModel?.cars ?? []
            )
        }
    }
    
    private var fallbackProfileImage: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private var carCollectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("profile.cars.collection".localized)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    Picker("profile.sort_by".localized, selection: $sortOption) {
                        Label("profile.sort.rarity".localized, systemImage: "star.fill").tag(CarSort.rarity)
                        Label("profile.sort.name".localized, systemImage: "textformat").tag(CarSort.name)
                        Label("profile.sort.date".localized, systemImage: "calendar").tag(CarSort.dateCollected)
                    }
                } label: {
                    Label("profile.sort".localized, systemImage: "arrow.up.arrow.down")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 10)
            
            if viewModel?.cars.isEmpty ?? true {
                Text("profile.cars.empty".localized)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel?.cars ?? [], id: \.userCarId) { car in
                        CarThumbnailView(car: car)
                            .padding(.bottom, 8)
                    }
                    
                    // Add loading indicator at the bottom of grid that appears when more cars can be loaded
                    if viewModel?.hasMoreCars ?? false {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.accentColor)
                            Spacer()
                        }
                        .frame(height: 50)
                        .onAppear {
                            // When this view appears (user scrolls to bottom), load more cars
                            Task {
                                try? await Task.sleep(for: .seconds(0.5))
                                if !(viewModel?.isLoadingMoreCars ?? true) {
                                    await viewModel?.loadMoreCars()
                                }
                            }
                        }
                        .gridCellColumns(columns.count) // Make the loader span all columns
                    }
                }
            }
        }
    }
    
    // Server-side sorting is now used instead of client-side sorting
    
    private func statView(number: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}
