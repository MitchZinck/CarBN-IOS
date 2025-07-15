import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddFriend = false
    @State private var selectedTab = 0
    @State private var showingFriendProfile = false
    @State private var selectedFriend: Friend?
    @State private var showLoading = false
    
    // Add these properties to make the view reusable
    var isModal = false
    @State private var selectedFriendId: Int?
    @State private var showFriendProfile = false
    var userId: Int?
    var userName: String?
    
    private var viewModel: FriendsViewModel { appState.friendsViewModel }
    private var title: String {
        if let userName = userName {
            return String(format: "friends.user_friends".localized, userName)
        }
        return "friends.title".localized
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Only show tabs in main view, not in modal
                    if !isModal {
                        ZStack(alignment: .topTrailing) {
                            Picker("", selection: $selectedTab) {
                                Text("friends.title".localized).tag(0)
                                if !viewModel.pendingRequests.isEmpty {
                                    Text(String(format: "friends.requests_count".localized, viewModel.pendingRequests.count)).tag(1)
                                } else {
                                    Text("friends.requests".localized).tag(1)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onAppear {
                                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                            }
                            
                            if !viewModel.pendingRequests.isEmpty && selectedTab != 1 {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -20, y: 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    ZStack {
                        if selectedTab == 0 || isModal {
                            if viewModel.friends.isEmpty && !showLoading {
                                friendsEmptyStateView
                            } else {
                                friendsList
                            }
                        } else {
                            if viewModel.pendingRequests.isEmpty && !showLoading {
                                emptyStateView
                            } else {
                                requestsList
                            }
                        }
                        
                        if showLoading {
                            ProgressView()
                                .tint(.accentColor)
                                .scaleEffect(1.5)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if isModal {
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
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddFriend = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                    }
                }
            }
            .alert("common.error".localized, isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("common.ok".localized) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingAddFriend) {
                addFriendSheet
            }
            .sheet(isPresented: $showFriendProfile) {
                if let friendId = selectedFriendId {
                    NavigationStack {
                        FriendProfileView(userId: friendId)
                    }
                }
            }
            .task {
                showLoading = true
                // Add minimum display time of 0.5 seconds
                let minimumLoadingTime = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                
                guard let currentUser = UserManager.shared.currentUser else { return }
                if let userId = userId {
                    await viewModel.loadFriends(userId: userId)
                } else {
                    await viewModel.loadPendingRequests()
                    await viewModel.loadFriends(userId: currentUser.id)
                }
                
                await minimumLoadingTime.value
                showLoading = false
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("friends.no_pending_requests".localized)
                .font(.headline)
                .foregroundStyle(.gray)
            
            Button {
                showingAddFriend = true
            } label: {
                Label("friends.add".localized, systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.pendingRequests) { request in
                    requestView(for: request)
                }
            }
        }
    }
    
    private func requestView(for request: FriendRequest) -> some View {
        let isCurrentUserSender = request.userId == UserManager.shared.currentUser?.id
        let displayName = isCurrentUserSender ? request.friendDisplayName : request.userName
        let displayId = isCurrentUserSender ? request.friendId : request.userId
        let requestedProfilePicture = isCurrentUserSender ? request.friendProfilePicture : request.userProfilePicture
        
        return HStack {
            if let profilePicture = requestedProfilePicture {
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
                .frame(width: 40, height: 40)
            } else {
                fallbackUserImage
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    UserNameButton(
                        name: displayName,
                        userId: displayId,
                        currentUserId: UserManager.shared.currentUser?.id
                    )
                    Text("#\(displayId)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            if isCurrentUserSender {
                HStack(spacing: 8) {
                    Text("friends.status.pending".localized)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }
            } else {
                HStack(spacing: 8) {
                    
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.handleRequest(requestId: request.id, accept: false)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.red)
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Circle())
                        }
                        
                        Button {
                            Task {
                                await viewModel.handleRequest(requestId: request.id, accept: true)
                                await viewModel.loadFriends(userId: UserManager.shared.currentUser?.id)
                                $selectedTab.wrappedValue = 0
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    HStack {
                        if let profilePicture = friend.profilePicture {
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
                            .frame(width: 40, height: 40)
                        } else {
                            fallbackUserImage
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                UserNameButton(
                                    name: friend.displayName,
                                    userId: friend.id,
                                    currentUserId: UserManager.shared.currentUser?.id
                                )
                                Text("#\(friend.id)")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            if viewModel.friendSubscriptionStatus[friend.id] == true {
                                ProBadgeView()
                            }
                        }
                        
                        Spacer()
                        if friend.id != UserManager.shared.currentUser?.id {
                            // Replace NavigationLink with:
                            Button {
                                selectedFriendId = friend.id
                                showFriendProfile = true
                            } label: {
                                Text("friends.view_profile".localized)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        // Load more friends when reaching the last item
                        if friend.id == viewModel.friends.last?.id && viewModel.hasMore {
                            Task {
                                await viewModel.loadMoreFriends(userId: userId)
                            }
                        }
                    }
                }
                
                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                }
            }
            
            if !viewModel.hasMore && !viewModel.friends.isEmpty {
                Text(String(format: "friends.total_count".localized, viewModel.total))
                    .foregroundStyle(.gray)
                    .padding(.vertical)
            }
        }
    }
    
    private var friendsEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("friends.empty".localized)
                .font(.headline)
                .foregroundStyle(.gray)
            
            Button {
                showingAddFriend = true
            } label: {
                Label("friends.add".localized, systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var addFriendSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("friends.search_placeholder".localized, text: Binding(
                        get: { viewModel.searchQuery },
                        set: { appState.friendsViewModel.searchQuery = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Button {
                        Task {
                            if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                await viewModel.searchUsers()
                            }
                        }
                    } label: {
                        Text("common.search".localized)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(!viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .tint(.accentColor)
                        .scaleEffect(1.5)
                    Spacer()
                } else if viewModel.hasSearched && viewModel.searchResults.isEmpty {
                    Spacer()
                    Text("friends.search.no_results".localized)
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.searchResults) { user in
                                FriendSearchResult(user: user) {
                                    Task {
                                        await viewModel.sendFriendRequest(to: user.id)
                                        viewModel.clearSearchState()
                                        showingAddFriend = false
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("friends.add".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(AppConstants.backgroundColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        viewModel.clearSearchState()
                        showingAddFriend = false
                    }
                    .foregroundStyle(.white)
                }
            }
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
