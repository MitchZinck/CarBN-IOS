import Foundation

enum TradeError: LocalizedError {
    case invalidTrade(String)
    case emptyTrade
    case invalidResponse(String)
    case subscriptionRequired(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTrade(let reason):
            return "Invalid trade: \(reason)"
        case .emptyTrade:
            return "Trade must include at least one car from either party"
        case .invalidResponse(let reason):
            return "Invalid trade response: \(reason)"
        case .subscriptionRequired(let party):
            return "Active subscription required for \(party)"
        }
    }
}

@MainActor
final class TradeService {
    static let shared = TradeService()
    
    static let tradeCreatedNotification = NSNotification.Name("TradeCreated")
    
    // Add task tracking
    private var currentFetchTask: Task<TradeHistoryResponse, Error>?
    
    func createTradeRequest(
        toUserId: Int,
        fromCarIds: [Int],
        toCarIds: [Int]
    ) async throws -> EmptyResponse {
        // Use cached subscription status
        let subscription = try await SubscriptionService.shared.getSubscriptionInfo()
        guard subscription.isActive else {
            throw TradeError.subscriptionRequired("initiating user")
        }
        
        // Validate trade request
        guard !fromCarIds.isEmpty || !toCarIds.isEmpty else {
            Logger.error("Attempted to create empty trade")
            throw TradeError.emptyTrade
        }
        
        Logger.info("Creating trade request - To: \(toUserId), From cars: \(fromCarIds), To cars: \(toCarIds)")
        
        let request = TradeRequest(
            userIdTo: toUserId,
            userFromCarIds: fromCarIds,
            userToCarIds: toCarIds
        )
        
        do {
            let response: EmptyResponse = try await APIClient.shared.post(
                endpoint: "/trade/request",
                body: request
            )
            Logger.info("Trade request created successfully")
            
            // Post notification when trade is created
            NotificationCenter.default.post(name: TradeService.tradeCreatedNotification, object: nil)
            
            return response
        } catch let error as APIError {
            if case .httpError(403, _) = error {
                // Force refresh subscription on 403 to sync with server
                _ = try? await SubscriptionService.shared.getSubscriptionInfo()
                throw TradeError.subscriptionRequired("target user")
            }
            Logger.error("Failed to create trade request: \(error)")
            throw error
        }
    }
    
    func respondToTrade(tradeId: Int, accept: Bool) async throws {
        // Use cached subscription status
        let subscription = try await SubscriptionService.shared.getSubscriptionInfo()
        guard subscription.isActive else {
            throw TradeError.subscriptionRequired("responding user")
        }
        
        let responseStr = accept ? "accept" : "decline"
        Logger.info("Responding to trade \(tradeId) with: \(responseStr)")
        
        let response = TradeResponse(
            tradeId: tradeId,
            response: responseStr
        )
        
        do {
            let _: EmptyResponse = try await APIClient.shared.post(
                endpoint: "/trade/respond",
                body: response
            )
            
            // If trade was accepted, refresh the user's car collection
            if accept {
                Logger.info("Trade accepted, refreshing user's car collection")
                CarService.shared.resetPaginationState()
            }
            
            Logger.info("Trade response processed successfully")
        } catch let error as APIError {
            switch error {
            case .httpError(403, _):
                // Force refresh subscription on 403 to sync with server
                _ = try? await SubscriptionService.shared.getSubscriptionInfo()
                throw TradeError.subscriptionRequired("other party")
            case .maxRetriesExceeded:
                // Only force logout if we're sure it's an auth issue
                Logger.error("Failed to process trade response due to auth error")
                throw error
            case .httpError(400, _):
                // Handle 400 errors without logging out - these are likely validation errors
                Logger.error("Trade response failed validation")
                throw TradeError.invalidResponse("The server rejected the trade response")
            case .httpError(404, _):
                // Handle 404 errors without logging out - these are likely validation errors
                Logger.error("Trade response found no cars to trade")
                throw TradeError.invalidResponse("The trade with ID \(tradeId) could not be found or had no cars to trade")
            default:
                Logger.error("Failed to process trade response due to an error: \(error)")
                throw error
            }
        } catch {
            Logger.error("Failed to process trade response: \(error)")
            throw error
        }
    }
    
    func fetchTradeHistory(page: Int = 1, pageSize: Int = 10) async throws -> TradeHistoryResponse {
        Logger.info("Fetching trade history - Page: \(page), PageSize: \(pageSize)")
        
        // Cancel any existing fetch task
        currentFetchTask?.cancel()
        
        let task = Task<TradeHistoryResponse, Error> {
            guard var url = try? APIClient.shared.makeURL(endpoint: "/trade/history") else {
                throw APIError.invalidURL
            }
            url.append(queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize))
            ])
            
            do {
                // Add a small delay for retries if this is a subsequent page (not first page)
                if page > 1 {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                }
                
                let response: TradeHistoryResponse = try await APIClient.shared.get(
                    endpoint: url.path + "?" + (url.query ?? "")
                )
                Logger.info("Successfully fetched trade history with \(response.trades.count) trades")
                return response
            } catch {
                // Check if it's a cancellation error
                if Task.isCancelled {
                    Logger.info("Trade history fetch was cancelled")
                    throw error
                }
                
                Logger.error("Failed to fetch trade history: \(error)")
                throw error
            }
        }
        
        // Store the current task
        currentFetchTask = task
        
        do {
            // Wait for the task to complete
            return try await task.value
        } catch {
            // Handle errors
            if Task.isCancelled {
                Logger.info("Trade history fetch was cancelled")
            }
            throw error
        }
    }
    
    func fetchTradeDetails(trade: Trade) async throws -> (fromCars: [Car], toCars: [Car]) {
        Logger.info("Fetching trade details for trade \(trade.id)")
        
        async let fromCars = CarService.shared.fetchSpecificUserCars(userCarIds: trade.fromUserCarIds)
        async let toCars = CarService.shared.fetchSpecificUserCars(userCarIds: trade.toUserCarIds)
        
        return try await (fromCars: fromCars, toCars: toCars)
    }

    func fetchTradeById(_ tradeId: Int) async throws -> Trade {
        Logger.info("Fetching trade with ID: \(tradeId)")
        
        do {
            let trade: Trade = try await APIClient.shared.get(
                endpoint: "/trade/\(tradeId)"
            )
            Logger.info("Successfully fetched trade \(tradeId)")
            return trade
        } catch let error as APIError {
            switch error {
            case .httpError(404, _):
                Logger.error("Trade \(tradeId) not found")
                throw TradeError.invalidResponse("Trade with ID \(tradeId) not found")
            case .httpError(400, _):
                Logger.error("Invalid trade ID format")
                throw TradeError.invalidResponse("Invalid trade ID format")
            default:
                Logger.error("Failed to fetch trade \(tradeId): \(error)")
                throw error
            }
        } catch {
            Logger.error("Failed to fetch trade \(tradeId): \(error)")
            throw error
        }
    }
}
