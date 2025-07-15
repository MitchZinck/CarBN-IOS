// MARK: - ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel?
    @State private var sortOption: CarSort = .rarity
    @State private var showingImagePicker = false
    @State private var isUploadingImage = false
    @State private var showingFriendSelector = false
    @State private var showFriendsList = false
    @State private var isEditingName = false
    @State private var newDisplayName = ""
    @State private var showingNameError = false
    @State private var nameErrorMessage = ""
    @State private var navigateToSettings = false
    @Environment(AppState.self) private var appState
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    
    private func handleLogout() async {
        // Use the centralized logout method from AuthService
        do {
            try await AuthService.shared.logout()
            Logger.info("[ProfileView] Logout completed successfully")
        } catch {
            Logger.error("[ProfileView] Logout failed: \(error)")
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor
                    .ignoresSafeArea()
                
                if let viewModel {
                    contentView
                        .alert("common.error".localized, isPresented: .constant(viewModel.errorMessage != nil)) {
                            Button("common.ok".localized) { viewModel.errorMessage = nil }
                        } message: {
                            Text(viewModel.errorMessage ?? "")
                        }
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(AppConstants.backgroundColor)
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
        }
        .onChange(of: sortOption) { _, newValue in
            if let viewModel = viewModel {
                Task {
                    await viewModel.updateSortOption(newSort: newValue)
                }
            }
        }
        .task {
            viewModel = await ProfileViewModel.create()
            await viewModel?.loadData()
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel?.cars.isEmpty ?? true && viewModel?.isLoading ?? false {
                    ProgressView("common.loading".localized)
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    profileHeader
                    carCollectionSection
                }
            }
            .padding()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .top) {
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        Group {
                            if let profileImage = UserManager.shared.cachedProfileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let user = viewModel?.user,
                                    let url = URL(string: "\(APIConstants.baseURL)/\(viewModel?.user?.profilePicture ?? "")"),
                                    user.profilePicture != nil {
                                CachedAsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure, .empty:
                                        fallbackProfileImage
                                    @unknown default:
                                        fallbackProfileImage
                                    }
                                }
                            } else {
                                fallbackProfileImage
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 2)
                        .overlay(
                            Group {
                                if isUploadingImage {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(1.5)
                                        .frame(width: 100, height: 100)
                                        .background(.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }
                        )
                    }
                    Spacer()
                }
                
                // Top left and right elements
                HStack {
                    // Currency on left
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("\(viewModel?.user?.currency ?? 0)")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            
            HStack(spacing: 4) {
                if isEditingName {
                    TextField("profile.display_name".localized, text: $newDisplayName)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .onAppear {
                            newDisplayName = viewModel?.user?.displayName ?? ""
                        }
                    
                    Button {
                        Task {
                            await updateDisplayName()
                        }
                    } label: {
                        Text("common.save".localized)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(newDisplayName.count < 3 || newDisplayName.count > 50)
                    
                    Button {
                        isEditingName = false
                        newDisplayName = ""
                    } label: {
                        Text("common.cancel".localized)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    Text(viewModel?.user?.displayName ?? "profile.default_user".localized)
                        .font(.title2.bold())
                    Text("#\(viewModel?.user?.id ?? 0)")
                        .font(.title3)
                        .foregroundStyle(.gray)
                    if let subscription = appState.subscription, subscription.isActive {
                        ProBadgeView()
                    }
                    
                    Button {
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                    }
                }
            }
            .foregroundColor(.white)
            .alert("common.error".localized, isPresented: $showingNameError) {
                Button("common.ok".localized) { showingNameError = false }
            } message: {
                Text(nameErrorMessage)
            }

            HStack(spacing: 30) {
                statView(number: "\(viewModel?.user?.carCount ?? 0)", label: "profile.stat.collected".localized)
                Button {
                    showFriendsList = true
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

            if let subscription = appState.subscription {
                if subscription.isActive {
                    Button {
                        showingFriendSelector = true
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
                // else {
                //     SubscriptionRequiredView(
                //                 title: "Can't Trade", 
                //                 message: "You need an active subscription to trade",
                //                 showSubscribeButton: true
                //             )
                // }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .navigationDestination(isPresented: $showFriendsList) {
            if let user = viewModel?.user {
                FriendsView(isModal: true, userId: user.id, userName: user.displayName)
            }
        }
        .sheet(isPresented: $showingFriendSelector) {
            NavigationStack {
                FriendSelectorView()
                    .background(AppConstants.backgroundColor)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: handleSelectedImage)
        }
    }
    
    private var fallbackProfileImage: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private func handleSelectedImage(_ image: UIImage?) {
        guard let image = image else { return }
        
        Task {
            isUploadingImage = true
            defer { isUploadingImage = false }
            
            do {
                try await ProfileService.shared.uploadProfilePicture(image)
                await viewModel?.loadUser()
            } catch {
                viewModel?.errorMessage = error.localizedDescription
            }
        }
    }

    // Server-side sorting is now used instead of client-side sorting
        
    private var carCollectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("profile.cars.title".localized)
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
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel?.cars ?? [], id: \.userCarId) { car in
                    CarThumbnailView(car: car)
                        .padding(.bottom, 8)
                }
                
                if !((viewModel?.cars ?? []).isEmpty) && viewModel?.hasMoreCars == true {
                    // Loading indicator at bottom
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.accentColor)
                        Spacer()
                    }
                    .frame(height: 50)
                    .onAppear {
                        Task { 
                            try? await Task.sleep(for: .seconds(0.5))
                            if !(viewModel?.isLoadingMoreCars ?? true) {
                                await viewModel?.loadMoreCars()
                            }
                        }
                    }
                    .gridCellColumns(columns.count)
                }
            }
        }
    }

    // Server-side sorting is now used instead of client-side caching
    
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
    
    private var verticalDivider: some View {
        Rectangle()
            .fill(.white)
            .frame(width: 1, height: 25)
    }
    
    private func updateDisplayName() async {
        guard newDisplayName.count >= 3 && newDisplayName.count <= 50 else {
            nameErrorMessage = "profile.name_error.length".localized
            showingNameError = true
            return
        }
        
        do {
            try await ProfileService.shared.updateDisplayName(newDisplayName)
            if var updatedUser = UserManager.shared.currentUser {
                updatedUser.displayName = newDisplayName
                UserManager.shared.updateCurrentUser(updatedUser)
            }
            isEditingName = false
        } catch {
            nameErrorMessage = "profile.name_error.update_failed".localized
            showingNameError = true
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState.shared)
}
