import Foundation

@Observable
@MainActor
final class CarService {
    static let shared = CarService()
    
    private(set) var userCars: [Car] = []
    
    // Pagination tracking properties
    private(set) var hasMoreCars: Bool = true
    private(set) var currentOffset: Int = 0
    private(set) var isFetchingCars: Bool = false
    private(set) var totalCarCount: Int = 0
    
    init() {
        // No cached data loading on init
    }

    func setUserCars(_ cars: [Car]) {
        userCars = cars
    }
    
    func fetchAndStoreUsersCars(limit: Int = 10, sort: CarSort? = nil) async throws {
        let batchSize = min(20, limit)
        // Guard against multiple simultaneous requests more aggressively
        guard !isFetchingCars && hasMoreCars else { return }
        guard let currentUser = UserManager.shared.currentUser else {
            Logger.error("No current user found")
            throw APIError.unauthorized
        }
        
        // Set flag before async code
        isFetchingCars = true
        
        do {
            // Use a local Task to handle cancellation gracefully
            let newCars: [Car] = try await withTaskCancellationHandler {
                try await self.fetchUsersCars(userId: currentUser.id, limit: batchSize, offset: currentOffset, sort: sort)
            } onCancel: {
                // Reset flag if cancelled
                Task { @MainActor in
                    self.isFetchingCars = false
                }
            }
            
            // Handle empty results even if no error
            if newCars.isEmpty {
                hasMoreCars = false
                isFetchingCars = false
                return
            }
            
            // Update in a single batch
            self.userCars.append(contentsOf: newCars)
            hasMoreCars = newCars.count >= limit
            currentOffset += newCars.count
        } catch APIError.httpError(404, _) {
            hasMoreCars = false
        } catch {
            Logger.error("Failed to fetch more cars: \(error)")
            throw error
        }
        
        // Always reset flag
        isFetchingCars = false
    }
    
    // New method to fetch and append more cars for pagination
    func fetchAndAppendUsersCars(limit: Int = 10, sort: CarSort? = nil) async throws {
        guard !isFetchingCars && hasMoreCars else { return }
        guard let currentUser = UserManager.shared.currentUser else {
            Logger.error("No current user found")
            throw APIError.unauthorized
        }
        
        isFetchingCars = true
        
        do {
            let newCars: [Car] = try await self.fetchUsersCars(userId: currentUser.id, limit: limit, offset: currentOffset, sort: sort)
            Logger.info("Successfully fetched \(newCars.count) more cars (offset: \(currentOffset))")
            
            // Create a set of existing IDs for fast lookup
            let existingCarIds = Set(self.userCars.compactMap { $0.userCarId })
            
            // Filter out any cars that already exist in the collection
            let uniqueNewCars = newCars.filter { car in
                guard let id = car.userCarId else { return false }
                return !existingCarIds.contains(id)
            }
            
            // Log if duplicates were found
            if uniqueNewCars.count < newCars.count {
                Logger.warning("Found \(newCars.count - uniqueNewCars.count) duplicate cars in pagination result")
            }
            
            // Append only unique cars
            self.userCars.append(contentsOf: uniqueNewCars)
            
            // Update pagination state - still use original count for determining if more data exists
            hasMoreCars = newCars.count >= limit
            currentOffset += newCars.count
            
            isFetchingCars = false
        } catch APIError.httpError(404, _) {
            Logger.info("No more cars found for current user")
            hasMoreCars = false
            isFetchingCars = false
        } catch {
            Logger.error("Failed to fetch more cars: \(error)")
            isFetchingCars = false
            throw error
        }
    }

    // Reset only pagination tracking without clearing cars
    func resetPaginationStateOnly() {
        currentOffset = userCars.count
        hasMoreCars = true
        isFetchingCars = false
    }
    
    // Reset pagination state and clear all user cars
    func resetPaginationState() {
        currentOffset = 0
        hasMoreCars = true
        isFetchingCars = false
        
        // Important: Also clear the userCars array to prevent data leakage between accounts
        userCars.removeAll()
        Logger.info("[CarService] Pagination state reset and user cars cleared")
    }
    
    func fetchUsersCars(userId: Int, limit: Int = 50, offset: Int = 0, sort: CarSort? = nil) async throws -> [Car] {
        var endpoint = "/user/\(userId)/cars"
        var hasQuery = false
        
        if limit > 0 {
            endpoint += "?limit=\(limit)"
            hasQuery = true
        }
        
        if offset > 0 {
            endpoint += hasQuery ? "&offset=\(offset)" : "?offset=\(offset)"
            hasQuery = true
        }
        
        if let sort = sort {
            let sortParam: String
            switch sort {
            case .rarity:
                sortParam = "rarity"
            case .name:
                sortParam = "name"
            case .dateCollected:
                sortParam = "date"
            }
            endpoint += hasQuery ? "&sort=\(sortParam)" : "?sort=\(sortParam)"
        }
        
        Logger.info("Fetching cars for user \(userId) with endpoint: \(endpoint)")
        let cars: [Car] = try await APIClient.shared.get(endpoint: endpoint)
        Logger.info("Successfully fetched \(cars.count) cars for user \(userId)")
        return cars
    }
    
    func fetchSpecificUserCars(userCarIds: [Int]) async throws -> [Car] {
        let idsString = userCarIds.map(String.init).joined(separator: ",")
        let endpoint = "/user/cars?ids=\(idsString)"
        Logger.info("Fetching specific cars with IDs: \(idsString)")
        let cars: [Car] = try await APIClient.shared.get(endpoint: endpoint)
        Logger.info("Successfully fetched \(cars.count) specific cars")
        return cars
    }
    
    func getLocalCars() -> [Car] {
        return userCars
    }
    
    func updateCarInMemory(updatedCar: Car) {
        if let index = userCars.firstIndex(where: { $0.userCarId == updatedCar.userCarId }) {
            var updatedCars = userCars
            updatedCars[index] = updatedCar
            userCars = updatedCars
        }
    }
    
    func removeCarFromMemory(userCarId: Int) {
        userCars = userCars.filter { $0.userCarId != userCarId }
    }
    
    func sellCar(userCarId: Int) async throws -> SellCarResponse {
        Logger.info("Attempting to sell car with userCarId: \(userCarId)")
        let endpoint = "/user/cars/\(userCarId)/sell"
        
        do {
            let response: SellCarResponse = try await APIClient.shared.post(endpoint: endpoint, body: EmptyRequest())
            Logger.info("Car sold successfully, earned \(response.currencyEarned) coins")
            
            // Update local currency
            if let user = UserManager.shared.currentUser {
                let newCurrency = user.currency + response.currencyEarned
                UserManager.shared.updateUserCurrency(newCurrency)
            }
            
            // Remove car from memory
            removeCarFromMemory(userCarId: userCarId)
            
            return response
        } catch {
            Logger.error("Failed to sell car: \(error)")
            throw error
        }
    }
    
    func upgradeCarImage(userCarId: Int) async throws -> CarImageResponse {
        Logger.info("Attempting to upgrade car image for userCarId: \(userCarId)")
        let endpoint = "/user/cars/\(userCarId)/upgrade-image"
        
        do {
            let response: CarImageResponse = try await APIClient.shared.post(endpoint: endpoint, body: EmptyRequest())
            Logger.info("Car image upgraded successfully")
            
            // Update in memory
            if let car = userCars.first(where: { $0.userCarId == userCarId }) {
                let updatedCar = car
                    .copy(withHighResImage: response.highResImage, withLowResImage: response.lowResImage)
                    .withPremiumImage(active: true)
                updateCarInMemory(updatedCar: updatedCar)
            }
            if let user = UserManager.shared.currentUser {
                // Use remaining currency from response if available, otherwise subtract 5000
                if let remainingCurrency = response.remainingCurrency {
                    UserManager.shared.updateUserCurrency(remainingCurrency)
                } else {
                    let newCurrency = user.currency - 5000  // 5000 is the upgrade cost
                    UserManager.shared.updateUserCurrency(newCurrency)
                }
            }
            
            return response
        } catch {
            Logger.error("Failed to upgrade car image: \(error)")
            throw error
        }
    }
    
    func revertCarImage(userCarId: Int) async throws -> CarImageResponse {
        Logger.info("Attempting to revert car image for userCarId: \(userCarId)")
        let endpoint = "/user/cars/\(userCarId)/revert-image"
        
        do {
            let response: CarImageResponse = try await APIClient.shared.post(endpoint: endpoint, body: EmptyRequest())
            Logger.info("Car image reverted successfully")
            
            // Update in memory
            if let car = userCars.first(where: { $0.userCarId == userCarId }) {
                let updatedCar = car
                    .copy(withHighResImage: response.highResImage, withLowResImage: response.lowResImage)
                    .withPremiumImage(active: false)
                updateCarInMemory(updatedCar: updatedCar)
            }
            
            return response
        } catch {
            Logger.error("Failed to revert car image: \(error)")
            throw error
        }
    }
    
    func fetchCarUpgrades(userCarId: Int) async throws -> [CarUpgrade] {
        Logger.info("Fetching upgrades for car: \(userCarId)")
        let endpoint = "/user/cars/\(userCarId)/upgrades"
        
        do {
            let upgrades: [CarUpgrade] = try await APIClient.shared.get(endpoint: endpoint)
            Logger.info("Successfully fetched \(upgrades.count) upgrades for car")
            return upgrades
        } catch {
            Logger.error("Failed to fetch car upgrades: \(error)")
            throw error
        }
    }
    
    func fetchAndCompareUsersCars(limit: Int = 20, sort: CarSort? = nil) async throws -> Bool {
        guard let currentUser = UserManager.shared.currentUser else {
            Logger.error("No current user found")
            throw APIError.unauthorized
        }
        
        let fetchedCars = try await fetchUsersCars(userId: currentUser.id, limit: limit, offset: 0, sort: sort)
        
        // Check if number of cars is different
        if fetchedCars.count != min(limit, userCars.count) {
            // Update cars and reset pagination
            userCars = fetchedCars
            currentOffset = fetchedCars.count
            hasMoreCars = fetchedCars.count >= limit
            isFetchingCars = false
            return true
        }
        
        // Check if cars themselves are different (by userCarId)
        let existingCarIds = Set(userCars.prefix(limit).map { $0.userCarId })
        let fetchedCarIds = Set(fetchedCars.map { $0.userCarId })
        
        if existingCarIds != fetchedCarIds {
            // Update cars and reset pagination
            userCars = fetchedCars
            currentOffset = fetchedCars.count
            hasMoreCars = fetchedCars.count >= limit
            isFetchingCars = false
            return true
        }
        
        // Check for property changes in existing cars
        for (index, fetchedCar) in fetchedCars.enumerated() {
            if index < userCars.count {
                if !carPropertiesMatch(fetchedCar, userCars[index]) {
                    // Update cars and reset pagination
                    userCars = fetchedCars
                    currentOffset = fetchedCars.count
                    hasMoreCars = fetchedCars.count >= limit
                    isFetchingCars = false
                    return true
                }
            }
        }
        
        // No changes detected
        return false
    }

    private func carPropertiesMatch(_ car1: Car, _ car2: Car) -> Bool {
        // Compare essential properties to detect changes
        return car1.userCarId == car2.userCarId &&
               car1.hasPremiumImage == car2.hasPremiumImage &&
               car1.lowResImage == car2.lowResImage &&
               car1.highResImage == car2.highResImage
    }
    
    // MARK: - Car Like Methods
    
    func likeCar(carId: Int) async throws -> Like {
        Logger.info("Liking car with ID: \(carId)")
        
        guard let userCarId = userCars.first(where: { $0.id == carId })?.userCarId else {
            throw APIError.invalidResponse
        }
        
        do {
            let like = try await LikeService.shared.likeCar(userCarId)
            
            // Update local car copy with new like state
            if let index = userCars.firstIndex(where: { $0.id == carId }) {
                let updatedCar = userCars[index].copy(
                    withLikesCount: userCars[index].likesCount + 1,
                    withIsLikedByCurrentUser: true
                )
                updateCarInMemory(updatedCar: updatedCar)
            }
            
            return like
        } catch {
            Logger.error("Failed to like car: \(error)")
            throw error
        }
    }
    
    func unlikeCar(carId: Int) async throws {
        Logger.info("Unliking car with ID: \(carId)")
        
        guard let userCarId = userCars.first(where: { $0.id == carId })?.userCarId else {
            throw APIError.invalidResponse
        }
        
        do {
            try await LikeService.shared.unlikeCar(userCarId)
            
            // Update local car copy with new like state
            if let index = userCars.firstIndex(where: { $0.id == carId }) {
                let likesCount = max(0, userCars[index].likesCount - 1)
                let updatedCar = userCars[index].copy(
                    withLikesCount: likesCount,
                    withIsLikedByCurrentUser: false
                )
                updateCarInMemory(updatedCar: updatedCar)
            }
        } catch {
            Logger.error("Failed to unlike car: \(error)")
            throw error
        }
    }
    
    func refreshCarLikesData(carId: Int) async throws {
        Logger.info("Refreshing like data for car with ID: \(carId)")
        
        guard let userCarId = userCars.first(where: { $0.id == carId })?.userCarId else {
            throw APIError.invalidResponse
        }
        
        do {
            async let likedStatus = LikeService.shared.checkIfUserLikedCar(userCarId: userCarId)
            async let count = LikeService.shared.getCarLikesCount(userCarId: userCarId)
            
            let (isUserLiked, likesCount) = try await (likedStatus, count)
            
            if let index = userCars.firstIndex(where: { $0.id == carId }) {
                let updatedCar = userCars[index].copy(
                    withLikesCount: likesCount,
                    withIsLikedByCurrentUser: isUserLiked
                )
                updateCarInMemory(updatedCar: updatedCar)
            }
        } catch {
            Logger.error("Failed to refresh car like data: \(error)")
            throw error
        }
    }
}
