import Foundation

@Observable
final class TradeDetailsViewModel {
    private(set) var fromUserCars: [Car] = []
    private(set) var toUserCars: [Car] = []
    private(set) var fromUser: User? = nil
    private(set) var toUser: User? = nil
    private(set) var isLoading = false
    var errorMessage: String?
    var showError = false

    func getUser(userId: Int) async -> User? {
        do {
            let user: User = try await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: userId))
            errorMessage = nil
            return user
        } catch {
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            Logger.error("Failed to load user profile: \(error)")
            return nil
        }
    }
    
    func loadTradeDetails(trade: Trade) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let fromCars: [Car] = try await CarService.shared.fetchSpecificUserCars(userCarIds: trade.fromUserCarIds)
            async let toCars: [Car] = try await CarService.shared.fetchSpecificUserCars(userCarIds: trade.toUserCarIds)
            
            let (loadedFromCars, loadedToCars) = try await (fromCars, toCars)
            
            fromUserCars = loadedFromCars
            toUserCars = loadedToCars

            if let fromUserData = await getUser(userId: trade.fromUserId) {
                fromUser = fromUserData
            }
            if let toUserData = await getUser(userId: trade.toUserId) {
                toUser = toUserData
            }
            
            Logger.info("Successfully loaded trade details: From user cars - \(fromUserCars.count), To user cars - \(toUserCars.count)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to load trade details: \(error)")
        }
    }
}
