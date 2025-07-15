import SwiftUI

@Observable
@MainActor
final class TradeViewModel {
    private(set) var fromUserSelectedCars: Set<Car> = Set<Car>()
    private(set) var toUserSelectedCars: Set<Car> = Set<Car>()
    private(set) var yourCars: [Car] = []
    var isLoading = false
    var isLoadingCars = false
    var errorMessage: String?
    var showError = false
    
    let toUserId: Int
    private let tradeService: TradeService
    private let carService: CarService
    private let subscriptionService: SubscriptionService
    private let maxCarsPerTrade = 5 // Limit number of cars per side in a trade
    
    init(toUserId: Int) {
        self.toUserId = toUserId
        self.tradeService = TradeService.shared
        self.carService = CarService.shared
        self.subscriptionService = SubscriptionService.shared
        
        // Load cars immediately
        Task {
            await loadYourCars()
        }
    }
    
    init(toUserId: Int, tradeService: TradeService) {
        self.toUserId = toUserId
        self.tradeService = tradeService
        self.carService = CarService.shared
        self.subscriptionService = SubscriptionService.shared
        
        // Load cars immediately
        Task {
            await loadYourCars()
        }
    }
    
    func loadYourCars() async {
        isLoadingCars = true
        defer { isLoadingCars = false }
        
        // Clear existing cars first to avoid stale data
        yourCars = []
        
        // Always fetch fresh cars first
        do {
            try await carService.fetchAndStoreUsersCars()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        yourCars = carService.getLocalCars()
    }
    
    func toggleCarSelection(car: Car, fromUser: Bool) {
        let targetSet = fromUser ? fromUserSelectedCars : toUserSelectedCars
        
        // Find if car is already selected using userCarId
        if let existingCar = targetSet.first(where: { $0.userCarId == car.userCarId }) {
            if fromUser {
                fromUserSelectedCars.remove(existingCar)
            } else {
                toUserSelectedCars.remove(existingCar)
            }
        } else {
            // Don't allow more than maxCarsPerTrade cars to be selected
            if targetSet.count >= maxCarsPerTrade {
                errorMessage = "Cannot select more than \(maxCarsPerTrade) cars per side in a trade"
                showError = true
                return
            }
            
            if fromUser {
                fromUserSelectedCars.insert(car)
            } else {
                toUserSelectedCars.insert(car)
            }
        }
    }
    
    func submitTrade() async {
        // Check subscription status first
        do {
            let otherUserStatus = try await subscriptionService.getUserSubscriptionStatus(userId: toUserId)
            if !otherUserStatus {
                errorMessage = "The other user doesn't have an active subscription required for trading"
                showError = true
                return
            }
            
            guard let myStatus = try? await subscriptionService.getSubscriptionInfo().isActive, myStatus else {
                errorMessage = "You need an active subscription to trade cars"
                showError = true
                return
            }
        } catch {
            errorMessage = "Failed to verify subscription status"
            showError = true
            return
        }
        
        // Validate trade basics
        guard validateTrade() else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await tradeService.createTradeRequest(
                toUserId: toUserId,
                fromCarIds: fromUserSelectedCars.map { $0.userCarId ?? 0 },
                toCarIds: toUserSelectedCars.map { $0.userCarId ?? 0 }
            )
            Logger.info("Trade submitted successfully")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to submit trade: \(error)")
        }
    }
    
    func respondToTrade(tradeId: Int, accept: Bool) async {
        // Only check subscription if accepting the trade
        if accept {
            guard let myStatus = try? await subscriptionService.getSubscriptionInfo().isActive, myStatus else {
                errorMessage = "You need an active subscription to accept trades"
                showError = true
                return
            }
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await tradeService.respondToTrade(tradeId: tradeId, accept: accept)
            Logger.info("Trade response submitted successfully")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to respond to trade: \(error)")
        }
    }
    
    private func validateTrade() -> Bool {
        // At least one car must be selected in total
        if fromUserSelectedCars.isEmpty && toUserSelectedCars.isEmpty {
            errorMessage = "Please select at least one car to trade"
            showError = true
            return false
        }
        
        // Validate car counts
        if fromUserSelectedCars.count > maxCarsPerTrade || toUserSelectedCars.count > maxCarsPerTrade {
            errorMessage = "Cannot trade more than \(maxCarsPerTrade) cars per side"
            showError = true
            return false
        }
        
        return true
    }
}
