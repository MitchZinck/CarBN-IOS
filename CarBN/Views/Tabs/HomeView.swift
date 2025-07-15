import SwiftUI
import Foundation

struct HomeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor.ignoresSafeArea()
                
                VStack {
                    if let viewModel = appState.homeViewModel {
                        HStack(spacing: 8) {
                            // Feed/Likes Picker
                            Picker("home.view".localized, selection: Binding(
                                get: { viewModel.selectedTab },
                                set: { viewModel.selectedTab = $0 }
                            )) {
                                Text("home.feed".localized).tag(HomeTab.feed)
                                Text("home.likes".localized + (viewModel.newLikesCount > 0 ? " (+\(viewModel.newLikesCount))" : ""))
                                    .tag(HomeTab.likes)
                            }
                            .pickerStyle(.segmented)
                            .onAppear {
                                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                            }
                            
                            // Feed type dropdown menu with fixed width for icon
                            Menu {
                                Button {
                                    if viewModel.selectedFeedType != .global {
                                        viewModel.selectedFeedType = .global
                                        Task { await viewModel.loadFeed() }
                                    }
                                } label: {
                                    Label("Global Feed", systemImage: "globe")
                                }
                                Button {
                                    if viewModel.selectedFeedType != .friends {
                                        viewModel.selectedFeedType = .friends
                                        Task { await viewModel.loadFeed() }
                                    }
                                } label: {
                                    Label("Friends Feed", systemImage: "person.2")
                                }
                            } label: {
                                // Fixed width for icon to prevent picker width jump
                                ZStack {
                                    // Both icons, but only one visible at a time
                                    Image(systemName: "globe")
                                        .opacity(viewModel.selectedFeedType == .global ? 1 : 0)
                                    Image(systemName: "person.2")
                                        .opacity(viewModel.selectedFeedType == .friends ? 1 : 0)
                                }
                                .frame(width: 32, height: 32) // Adjust width as needed
                                .foregroundColor(.accentColor)
                                .imageScale(.large)
                                .accessibilityLabel(viewModel.selectedFeedType == .global ? "Show Global Feed" : "Show Friends Feed")
                            }
                            .padding(.leading, 4)
                            .help(viewModel.selectedFeedType == .global ? "Show Global Feed" : "Show Friends Feed")
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        ZStack {
                            if viewModel.selectedTab == .feed {
                                feedView(viewModel: viewModel)
                            } else {
                                likesView(viewModel: viewModel)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ProgressView()
                            .tint(Color.accentColor)
                            .scaleEffect(1.5)
                    }
                }
            }
            .navigationTitle("home.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("common.error".localized, isPresented: Binding(
                get: { appState.homeViewModel?.showError ?? false },
                set: { if let viewModel = appState.homeViewModel { viewModel.showError = $0 }}
            )) {
                Button("common.ok".localized) { 
                    if let viewModel = appState.homeViewModel {
                        viewModel.showError = false 
                    }
                }
            } message: {
                Text(appState.homeViewModel?.errorMessage ?? "")
            }
            .onChange(of: appState.homeViewModel?.selectedTab) { oldValue, newValue in
                guard let newValue else { return }
                Task {
                    switch newValue {
                    case .feed:
                        await appState.homeViewModel?.loadFeed()
                    case .likes:
                        await appState.homeViewModel?.loadReceivedLikes()
                    }
                }
            }
            .onChange(of: appState.homeViewModel?.selectedFeedType) { _, _ in
                Task { await appState.homeViewModel?.loadFeed() }
            }
            .task {
                if appState.isAuthenticated {
                    // Use the new method in AppState to initialize the HomeViewModel
                    await appState.refreshIfNeeded()
                    
                    // Load the feed if the homeViewModel is now available
                    if let homeViewModel = appState.homeViewModel {
                        await homeViewModel.loadFeed()
                    }
                }
            }
        }
    }
    
    private func feedView(viewModel: HomeViewModel) -> some View {
        ZStack {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                ProgressView()
                    .tint(Color.accentColor)
                    .scaleEffect(1.5)
            } else if viewModel.feedItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.feedItems) { item in
                            FeedItemView(item: item, viewModel: viewModel)
                        }
                        
                        if !viewModel.feedItems.isEmpty {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .tint(.accentColor)
                                }
                                Spacer()
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreFeed()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadFeed()
                }
            }
        }
    }
    
    private func likesView(viewModel: HomeViewModel) -> some View {
        ZStack {
            if viewModel.isLoading && viewModel.receivedLikes.isEmpty {
                ProgressView()
                    .tint(Color.accentColor)
                    .scaleEffect(1.5)
            } else if viewModel.receivedLikes.isEmpty {
                emptyLikesView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.receivedLikes, id: \.id) { like in
                            LikeItemView(like: like, viewModel: viewModel)
                        }
                        
                        if !viewModel.receivedLikes.isEmpty {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .tint(.accentColor)
                                }
                                Spacer()
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreReceivedLikes()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadReceivedLikes()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("home.feed.empty".localized)
                .font(.headline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var emptyLikesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("home.likes.empty".localized)
                .font(.headline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
    }
}

struct FeedItemView: View {
    private struct UserId: Identifiable {
        let id: Int
    }
    
    let item: FeedItem
    @State private var car: Car?
    @State private var trade: Trade?
    let viewModel: HomeViewModel
    @State private var showingCarDetail = false
    @State private var showingTradeDetails = false
    @State private var selectedUserId: UserId?
    private let currentUserId = UserManager.shared.currentUser?.id
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            itemContent
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if item.type != .friendAccepted {
                HStack {
                    Text("\(item.likeCount)")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                    
                    Button {
                        Task {
                            await viewModel.toggleLike(for: item)
                        }
                    } label: {
                        Image(systemName: item.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundStyle(item.isLikedByCurrentUser ? Color.red : Color.white)
                    }
                }
                .padding(12)
            }
        }
        .task {
            switch item.type {
            case .carScanned:
                car = await viewModel.getCar(for: item)
            case .tradeCompleted:
                trade = await viewModel.getTrade(for: item)
            default:
                break
            }
        }
        .sheet(isPresented: $showingCarDetail) {
            if let car = car {
                CarDetailView(car: car)
            }
        }
        .sheet(isPresented: $showingTradeDetails) {
            if let trade = trade {
                TradeDetailsView(trade: trade, onRespond: { _ in })
            }
        }
        .sheet(item: $selectedUserId) { userId in
            FriendProfileView(userId: userId.id)
        }
    }
    
    @ViewBuilder
    private var itemContent: some View {
        switch item.type {
        case .carScanned:
            carScannedContent
        case .tradeCompleted:
            tradeCompletedContent
        case .friendAccepted:
            friendAcceptedContent
        }
    }
    
    private func profileImage(path: String?) -> some View {
        Group {
            if let profilePicture = path,
               let url = URL(string: "\(APIConstants.baseURL)/\(profilePicture)") {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty, _:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.gray)
                            }
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
    }
    
    private var carScannedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                profileImage(path: item.userProfilePicture)
                UserNameButton(
                    name: item.userName,
                    userId: item.userId,
                    currentUserId: currentUserId
                )
                Text("feed.action.scanned".localized)
                    .foregroundStyle(.white)
            }
            .font(.headline)
            
            if let car = car {
                Button {
                    showingCarDetail = true
                } label: {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            CarThumbnailView(car: car)
                                .frame(width: 120, height: 120)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(car.make) \(car.model)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                
                                HStack {
                                    Text(String(car.year))
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    if let trim = car.trim {
                                        Text(trim)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.3))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                
                                // Specifications Grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    specItem(
                                        title: "car.horsepower.short".localized,
                                        value: car.horsepower.map { "\($0)" } ?? "common.na".localized,
                                        icon: "bolt.fill"
                                    )
                                    specItem(
                                        title: "car.top_speed".localized,
                                        value: car.topSpeed.map { "\($0) mph" } ?? "common.na".localized,
                                        icon: "speedometer"
                                    )
                                    specItem(
                                        title: "car.acceleration".localized,
                                        value: car.acceleration.map { String(format: "%.1fs", $0) } ?? "common.na".localized,
                                        icon: "timer"
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("feed.loading.car_details".localized)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    private func specItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var tradeCompletedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack {
                    profileImage(path: item.userProfilePicture)
                    UserNameButton(
                        name: item.userName,
                        userId: item.userId,
                        currentUserId: currentUserId
                    )
                }
                Label("", systemImage: "arrow.left.arrow.right")
                    .foregroundStyle(Color.accentColor)
                    .background(Color.accentColor.opacity(0))
                HStack {
                    profileImage(path: item.relatedUserProfilePicture)
                    UserNameButton(
                        name: item.relatedUserName,
                        userId: item.relatedUserId ?? 0,
                        currentUserId: currentUserId
                    )
                }
            }
            .font(.headline)
            
            if let trade = trade {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(format: "feed.trade.cars_offered".localized, trade.fromUserCarIds.count))
                        Image(systemName: "arrow.right")
                        Text(String(format: "feed.trade.cars_received".localized, trade.toUserCarIds.count))
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                    
                    Text("feed.trade.tap_for_details".localized)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 4)
                }
            } else {
                Text("feed.loading.trade_details".localized)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
        .onTapGesture {
            if trade != nil {
                showingTradeDetails = true
            }
        }
    }
    
    private var friendAcceptedContent: some View {
        HStack(spacing: 8) {
            profileImage(path: item.userProfilePicture)
            UserNameButton(
                name: item.userName,
                userId: item.userId,
                currentUserId: currentUserId
            )
            Text("feed.action.friended".localized)
                .foregroundStyle(.white)
            profileImage(path: item.relatedUserProfilePicture)
            UserNameButton(
                name: item.relatedUserName,
                userId: item.relatedUserId ?? 0,
                currentUserId: currentUserId
            )
        }
        .font(.headline)
    }
}

struct LikeItemView: View {
    let like: Like
    @State private var feedItem: FeedItem?
    @State private var userDetails: User?
    @State private var car: Car?
    @State private var trade: Trade?
    @State private var isShowingFeedItem = false
    @State private var isShowingCarDetail = false
    @State private var isLoading = true
    @State private var viewModel: HomeViewModel

    init(like: Like, viewModel: HomeViewModel) {
        self.like = like
        self.viewModel = viewModel
    }
    
    var body: some View {
        Button {
            guard !isLoading else { return }
            
            // For car likes, show car detail directly, for feed likes show feed item detail
            if like.isCarLike {
                isShowingCarDetail = true
            } else {
                isShowingFeedItem = true
            }
        } label: {
            HStack(spacing: 12) {
                // Profile Image
                Group {
                    if isLoading {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                    } else if let userDetails {
                        CachedAsyncImage(url: URL(string: "\(APIConstants.baseURL)/\(userDetails.profilePicture ?? "")")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty, _:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.gray)
                                    }
                            }
                        }
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userDetails?.displayName ?? "common.loading".localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .redacted(reason: isLoading ? .placeholder : [])
                    
                    if isLoading {
                        Text("common.loading".localized)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .redacted(reason: .placeholder)
                    } else if let feedItem {
                        switch feedItem.type {
                        case .carScanned:
                            Text("feed.like.car_scan".localized)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        case .tradeCompleted:
                            Text("feed.like.trade".localized)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        default:
                            Text("feed.like.post".localized)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    } else if like.isCarLike {
                        Text("feed.like.car".localized)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
                
                Spacer()
                
                Text(like.createdAt.timeAgo())
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.trailing, 8)
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingCarDetail) {
            if let car = car {
                CarDetailView(car: car)
            } else {
                ProgressView("common.loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppConstants.backgroundColor.ignoresSafeArea())
            }
        }
        .sheet(isPresented: $isShowingFeedItem) {
            NavigationStack {
                if let feedItem = feedItem {
                    FeedItemDetailsSheet(feedItem: feedItem, car: car, trade: trade, viewModel: viewModel)
                } else {
                    ProgressView("common.loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppConstants.backgroundColor.ignoresSafeArea())
                }
            }
        }
        .task {
            do {
                async let userDetailsResult = APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: like.userId)) as User
                
                if like.isCarLike, let userCarId = like.userCarId {
                    // For car likes, fetch the car directly
                    let cars = try await CarService.shared.fetchSpecificUserCars(userCarIds: [userCarId])
                    self.car = cars.first
                    self.userDetails = try await userDetailsResult
                } else {
                    // For feed item likes
                    async let feedItemResult = FeedService.shared.fetchFeedItem(id: like.targetId)
                    let (userDetails, feedItemData) = try await (userDetailsResult, feedItemResult)
                    self.userDetails = userDetails
                    
                    // Create a modified copy of the feed item with user details
                    var modifiedFeedItem = feedItemData
                    
                    // Copy user details
                    modifiedFeedItem.userName = try? await (APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: feedItemData.userId)) as User).displayName
                    if let relatedUserId = feedItemData.relatedUserId {
                        modifiedFeedItem.relatedUserName = try? await (APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: relatedUserId)) as User).displayName
                    }
                    
                    self.feedItem = modifiedFeedItem
    
                    switch feedItemData.type {
                    case .carScanned:
                        let cars = try await CarService.shared.fetchSpecificUserCars(userCarIds: [feedItemData.referenceId])
                        self.car = cars.first
                    case .tradeCompleted:
                        self.trade = try await TradeService.shared.fetchTradeById(feedItemData.referenceId)
                    default:
                        break
                    }
                }
                
                isLoading = false
            } catch {
                Logger.error("Error loading like item data: \(error)")
                isLoading = false
            }
        }
    }
}

struct FeedItemDetailsSheet: View {
    let feedItem: FeedItem
    let car: Car?
    let trade: Trade?
    @State var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var showingTradeDetails = false
    @State private var showingCarDetail = false
    
    init(feedItem: FeedItem, car: Car?, trade: Trade?, viewModel: HomeViewModel) {
        self.feedItem = feedItem
        self.car = car
        self.trade = trade
        self.viewModel = viewModel
        // Initialize state properties after self init
        _isLiked = State(initialValue: feedItem.isLikedByCurrentUser)
        _likeCount = State(initialValue: feedItem.likeCount)
    }
    
    private func specItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // When toggling like, update the source feedItem in viewModel
    private func updateLikeStatus() async {
        if let index = viewModel.feedItems.firstIndex(where: { $0.id == feedItem.id }) {
            viewModel.feedItems[index].isLikedByCurrentUser = isLiked
            viewModel.feedItems[index].likeCount = likeCount
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                feedItemContent
            }
            .padding()
        }
        .background(AppConstants.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("feed.details".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingCarDetail) {
            if let car = car {
                CarDetailView(car: car)
            }
        }
    }
    
    @ViewBuilder
    private var feedItemContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch feedItem.type {
            case .carScanned:
                if let car = car {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            UserNameButton(
                                name: feedItem.userName,
                                userId: feedItem.userId,
                                currentUserId: UserManager.shared.currentUser?.id
                            )
                            Text("feed.action.scanned".localized)
                                .foregroundStyle(.white)
                        }
                        .font(.headline)
                        
                        Button {
                            showingCarDetail = true
                        } label: {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    CarThumbnailView(car: car)
                                        .frame(width: 120, height: 120)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(car.make) \(car.model)")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        
                                        HStack {
                                            Text(String(car.year))
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.blue.opacity(0.3))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            
                                            if let trim = car.trim {
                                                Text(trim)
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.white.opacity(0.3))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: 8) {
                                            specItem(
                                                title: "car.horsepower.short".localized,
                                                value: car.horsepower.map { "\($0)" } ?? "common.na".localized,
                                                icon: "bolt.fill"
                                            )
                                            specItem(
                                                title: "car.top_speed".localized,
                                                value: car.topSpeed.map { "\($0) mph" } ?? "common.na".localized,
                                                icon: "speedometer"
                                            )
                                            specItem(
                                                title: "car.acceleration".localized,
                                                value: car.acceleration.map { String(format: "%.1fs", $0) } ?? "common.na".localized,
                                                icon: "timer"
                                            )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            case .tradeCompleted:
                if let trade = trade {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            UserNameButton(
                                name: feedItem.userName,
                                userId: feedItem.userId,
                                currentUserId: UserManager.shared.currentUser?.id
                            )
                            Label("", systemImage: "arrow.left.arrow.right")
                                .foregroundStyle(Color.accentColor)
                            UserNameButton(
                                name: feedItem.relatedUserName,
                                userId: feedItem.relatedUserId ?? 0,
                                currentUserId: UserManager.shared.currentUser?.id
                            )
                        }
                        .font(.headline)
                        
                        Button {
                            showingTradeDetails = true
                        } label: {
                            TradeDetailsSection(trade: trade)
                        }
                    }
                }
            case .friendAccepted:
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if feedItem.type != .friendAccepted {
                HStack {
                    Text("\(likeCount)")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                    
                    Button {
                        Task {
                            let completed = await viewModel.toggleLike(for: feedItem)
                            if completed {
                                isLiked.toggle()
                                likeCount += isLiked ? 1 : -1
                                await updateLikeStatus()
                            }
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? Color.red : Color.white)
                    }
                }
                .padding(12)
            }
        }
        .sheet(isPresented: $showingTradeDetails) {
            if let trade = trade {
                TradeDetailsView(trade: trade, onRespond: { _ in })
            }
        }
    }
}

private struct TradeDetailsSection: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: "feed.trade.cars_offered".localized, trade.fromUserCarIds.count))
                Image(systemName: "arrow.right")
                Text(String(format: "feed.trade.cars_received".localized, trade.toUserCarIds.count))
            }
            .font(.caption)
            .foregroundStyle(.gray)
            
            Text("feed.trade.tap_for_details".localized)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
