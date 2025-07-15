import SwiftUI

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

struct CarDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var isLoading = false
    @State private var isUpgrading = false
    @State private var showingSellConfirmation = false
    @State private var showingUpgradeConfirmation = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingRevertConfirmation = false
    @State private var isLiked = false
    @State private var likesCount = 0
    @State private var isLikeLoading = false
    
    // Share-related state
    @State private var isSharingLoading = false
    @State private var shareURL: URL?
    
    // Update to observe car from CarService
    @Environment(CarService.self) private var carService
    let initialCar: Car
    
    var currentCar: Car {
        carService.userCars.first(where: { $0.userCarId == initialCar.userCarId }) ?? initialCar
    }
    
    init(car: Car) {
        self.initialCar = car
        self._likesCount = State(initialValue: car.likesCount)
        self._isLiked = State(initialValue: car.isLikedByCurrentUser)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    carImageSection
                        .frame(height: 200)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack (alignment: .leading, spacing: 8) {
                            HStack{
                                Button {
                                    Task {
                                        await toggleLike()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(isLiked ? .white : .white.opacity(0.9))
                                        Text("\(likesCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isLiked ? Color.red : Color.black.opacity(0.6))
                                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(isLiked ? Color.red.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isLikeLoading)
                                .scaleEffect(isLikeLoading ? 0.9 : 1.0)
                                .animation(.spring(response: 0.3), value: isLikeLoading)
                                .animation(.spring(response: 0.3), value: isLiked)
                                
                                if let trim = currentCar.trim {
                                    TrimBadgeView(trim: trim)
                                        .padding(.trailing, 4)
                                }
                                RarityBadgeView(rarity: currentCar.rarity ?? 1)
                            }
                            Text("\(currentCar.make) \(currentCar.model)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                        specificationsGrid
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if let userCarId = currentCar.userCarId, let userId = currentCar.userId, userId == UserManager.shared.currentUser?.id {
                            HStack(spacing: 12) {
                                    imageUpgradeButton
                                    Button {
                                        showingSellConfirmation = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "dollarsign.circle.fill")
                                            Text("car.details.sell".localized)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.8))
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .disabled(isLoading)
                                    .alert("car.details.sell_title".localized, isPresented: $showingSellConfirmation) {
                                        Button("common.cancel".localized, role: .cancel) { }
                                        Button("car.details.sell".localized, role: .destructive) {
                                            Task {
                                                await sellCar(userCarId: userCarId)
                                            }
                                        }
                                    } message: {
                                        let coins = calculateCoins(rarity: currentCar.rarity ?? 1)
                                        Text("car.details.sell_message".localizedFormat(coins))
                                    }
                            }
                            .padding(.horizontal)
                        }
                        
                        sectionHeader("car.details.overview".localized)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            detailRow(title: "car.year".localized, value: "\(currentCar.year)")
                            if let dateCollected = currentCar.dateCollected {
                                detailRow(title: "car.details.collected".localized, value: dateCollected.timeAgo())
                            }
                            if let trim = currentCar.trim {
                                detailRow(title: "car.details.trim".localized, value: trim)
                            }
                            if let price = currentCar.price {
                                detailRow(title: "car.details.value".localized, value: "$\(price)")
                            }
                            if let engineType = currentCar.engineType {
                                detailRow(title: "car.details.engine_type".localized, value: engineType)
                            }
                            if let drivetrain = currentCar.drivetrainType {
                                detailRow(title: "car.details.drivetrain".localized, value: drivetrain)
                            }
                            if let weight = currentCar.curbWeight {
                                detailRow(title: "car.details.weight".localized, value: "car.details.weight_unit".localizedFormat(Int(weight)))
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        if let description = currentCar.description {
                            sectionHeader("car.details.description".localized)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading) {
                                Text(description)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button with loading state
                        Button {
                            Task {
                                await createShareLink()
                            }
                        } label: {
                            ZStack {
                                if isSharingLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.footnote)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentColor)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            )
                            .foregroundStyle(.white)
                        }
                        .disabled(isSharingLoading)
                        
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
            }
            .background(AppConstants.backgroundColor)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .alert("common.error".localized, isPresented: $showingError) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage ?? "error.unknown".localized)
        }
        .alert("car.details.upgrade_title".localized, isPresented: $showingUpgradeConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("car.details.upgrade".localized) {
                Task {
                    if let userCarId = currentCar.userCarId {
                        await upgradeCarImage(userCarId: userCarId)
                    }
                }
            }
        } message: {
            Text("car.details.upgrade_message".localized)
        }
        .alert("car.details.revert_title".localized, isPresented: $showingRevertConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("car.details.revert".localized, role: .destructive) {
                Task {
                    if let userCarId = currentCar.userCarId {
                        await revertCarImage(userCarId: userCarId)
                    }
                }
            }
        } message: {
            Text("car.details.revert_message".localized)
        }
        .task {
            await loadLikeData()
        }
    }
    
    private func sellCar(userCarId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await carService.sellCar(userCarId: userCarId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func calculateCoins(rarity: Int) -> Int {
        switch rarity {
        case 1: return 500
        case 2: return 750
        case 3: return 1250
        case 4: return 2000
        case 5: return 5000
        default: return 50
        }
    }
    
    private func handleUpgrade() {
        guard let subscription = appState.subscription else { return }
        
        if (!subscription.isActive) {
            errorMessage = "car.details.error.subscription".localized
            showingError = true
            return
        }
        
        if let currentUser = UserManager.shared.currentUser,
           currentUser.currency < 5000 {
            errorMessage = "car.details.error.insufficient_coins".localized
            showingError = true
            return
        }
        
        showingUpgradeConfirmation = true
    }
    
    private func upgradeCarImage(userCarId: Int) async {
        isLoading = true
        isUpgrading = true
        defer { 
            isLoading = false
            isUpgrading = false
        }
        
        do {
            _ = try await carService.upgradeCarImage(userCarId: userCarId)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func revertCarImage(userCarId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await carService.revertCarImage(userCarId: userCarId)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func toggleLike() async {
        isLikeLoading = true
        defer { isLikeLoading = false }
        
        do {
            if isLiked {
                // Pass the userCarId directly to LikeService
                try await LikeService.shared.unlikeCar(currentCar.userCarId ?? 0)
                isLiked = false
                likesCount -= 1
            } else {
                // Pass the userCarId directly to LikeService
                _ = try await LikeService.shared.likeCar(currentCar.userCarId ?? 0)
                isLiked = true
                likesCount += 1
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func loadLikeData() async {
        guard let userCarId = currentCar.userCarId else { return }
        
        do {
            async let likedStatus = LikeService.shared.checkIfUserLikedCar(userCarId: userCarId)
            async let count = LikeService.shared.getCarLikesCount(userCarId: userCarId)
            
            let (isUserLiked, likesCountValue) = try await (likedStatus, count)
            
            isLiked = isUserLiked
            likesCount = likesCountValue
            
            // Update the car in memory
            if let car = carService.userCars.first(where: { $0.userCarId == userCarId }) {
                let updatedCar = car.copy(
                    withLikesCount: likesCountValue,
                    withIsLikedByCurrentUser: isUserLiked
                )
                carService.updateCarInMemory(updatedCar: updatedCar)
            }
        } catch {
            Logger.error("Failed to load car like data: \(error)")
        }
    }
    
    private var carImageSection: some View {
        Group {
            if !currentCar.highResImageURL.isEmpty {
                CachedAsyncImage(url: URL(string: currentCar.highResImageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .overlay {
                                if isUpgrading {
                                    ZStack {
                                        Color.black.opacity(0.3)
                                        VStack(spacing: 12) {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(1.5)
                                            Text("Enhancing Image...")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                    }
                                }
                            }
                    case .failure, .empty, _:
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "car.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            )
                    }
                }
                .id(currentCar.highResImageURL)
                .clipped()
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white.opacity(0.5))
                    )
            }
        }
    }
    
    private var imageUpgradeButton: some View {
        Button {
            if currentCar.hasPremiumImage {
                showingRevertConfirmation = true
            } else {
                handleUpgrade()
            }
        } label: {
            HStack {
                Image(systemName: currentCar.hasPremiumImage ? "arrow.uturn.backward.circle.fill" : "arrow.up.circle.fill")
                Text(currentCar.hasPremiumImage ? "Revert" : "Upgrade")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isLoading)
    }
    
    private var specificationsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            specificationItem(
                title: "car.details.specs.horsepower".localized,
                value: currentCar.horsepower.map { "car.details.specs.horsepower_value".localizedFormat($0) } ?? "common.na".localized,
                icon: "bolt.fill"
            )
            
            specificationItem(
                title: "car.details.specs.top_speed".localized,
                value: currentCar.topSpeed.map { "car.details.specs.top_speed_value".localizedFormat($0) } ?? "common.na".localized,
                icon: "speedometer"
            )
            
            specificationItem(
                title: "car.details.specs.acceleration".localized,
                value: currentCar.acceleration.map { "car.details.specs.acceleration_value".localizedFormat($0) } ?? "common.na".localized,
                icon: "timer"
            )
        }
    }
    
    private func specificationItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.white)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
    
    // Simplified share link creation function to directly use the system share sheet
    private func createShareLink() async {
        guard let userCarId = currentCar.userCarId else {
            errorMessage = "Cannot share this car"
            showingError = true
            return
        }
        
        isSharingLoading = true
        
        do {
            // Call the API to create a share link
            let endpoint = "/user/cars/\(userCarId)/share"
            let shareResponse: [String: String] = try await APIClient.shared.post(endpoint: endpoint, body: EmptyRequest())
            
            if let shareURLString = shareResponse["share_url"], let url = URL(string: shareURLString) {
                shareURL = url
                
                // Present share sheet on the main thread with just the URL
                await MainActor.run {
                    isSharingLoading = false
                    presentStandardShareSheet(url: url)
                }
            } else {
                throw NSError(domain: "ShareError", code: 0, 
                             userInfo: [NSLocalizedDescriptionKey: "Invalid share URL received"])
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create share link: \(error.localizedDescription)"
                showingError = true
                Logger.error("Failed to create share link: \(error)")
                isSharingLoading = false
            }
        }
    }
    
    // Simplified method for presenting the standard share sheet
    private func presentStandardShareSheet(url: URL) {
        // Prepare share items
        var activityItems: [Any] = []
        
        // Title with car info
        let shareTitle = "Check out this \(currentCar.year) \(currentCar.make) \(currentCar.model) on CarBN!"
        activityItems.append(shareTitle)
        
        // Add the URL
        activityItems.append(url)
        
        // Get the current window scene for iOS 15+
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Find the top-most presented controller to present from
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                // Don't go into UIActivityViewController or we'll have problems
                if presented is UIActivityViewController {
                    break
                }
                topController = presented
            }
            
            // Create and present the system share sheet with more options
            let activityVC = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // Exclude activity types that might cause problems
            activityVC.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]
            
            // Make sure we wait a brief moment before trying to present the sheet
            // to allow any current presentation to complete dismissal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Fix for iPad presentation
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(
                        x: UIScreen.main.bounds.midX,
                        y: UIScreen.main.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popover.permittedArrowDirections = []
                }
                
                // Present the activity sheet
                topController.present(activityVC, animated: true)
            }
        }
    }
}

#if DEBUG
struct CarDetailView_Previews: PreviewProvider {
    static var previewCar: Car {
        Car(
            id: 1,
            userCarId: 1,
            userId: 1,
            make: "Porsche",
            model: "911 GT3 RS",
            trim: "RS",
            year: "2021-2023",
            color: "Racing Yellow",
            horsepower: 518,
            torque: 346,
            topSpeed: 184,
            acceleration: 3.2,
            engineType: "4.0L Flat-6",
            drivetrainType: "RWD",
            curbWeight: 1450,
            price: 225250,
            rarity: 5,
            description: "The 2023 Porsche 911 GT3 RS is the most extreme, track-focused version of the 992-generation 911. It features advanced aerodynamics, including a massive rear wing with DRS, and a naturally aspirated 4.0L flat-six engine.",
            lowResImage: nil,
            highResImage: nil,
            dateCollected: nil,
            upgrades: nil,
            likesCount: 120,
            isLikedByCurrentUser: true
        )
    }
    
    static var previews: some View {
        CarDetailView(car: previewCar)
    }
}
#endif
