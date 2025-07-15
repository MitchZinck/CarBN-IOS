import Foundation
import StoreKit

@Observable
@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()
    
    private(set) var currentSubscription: SubscriptionInfo?
    private(set) var availableProducts: [SubscriptionProduct] = []
    private(set) var storeProducts: [Product] = []
    private(set) var purchaseInProgress = false
    private(set) var error: Error?
    
    private var subscriptionProductIDs = [
        "com.mzinck.carbn.subscription.monthly.basic1",
        "com.mzinck.carbn.subscription.monthly.standard",
        "com.mzinck.carbn.subscription.monthly.premium"
    ]
    
    private var scanPackProductIDs = [
        "com.mzinck.carbn.iap.scanpack.tencredits",
        "com.mzinck.carbn.iap.scanpack.fiftycredits",
        "com.mzinck.carbn.iap.scanpack.onehundredcredits"
    ]
    
    // We need to avoid the nonisolated modifier on a mutable property
    // Instead, use a backing Task property
    private(set) var _updates: Task<Void, Never>?
    
    func getUpdates() -> Task<Void, Never>? {
        return _updates
    }
    
    init() {
    Logger.info("Initializing SubscriptionService")
    
        // Create the task without unsafe self capture
        _updates = Task.detached {
            // Use a separate function that doesn't capture self
            await SubscriptionService.startListeningForTransactions()
        }
    }

    // Static method to handle transactions without capturing instance
    private static func startListeningForTransactions() async {
        Logger.info("Transaction listener started")
        for await result in Transaction.updates {
            await processTransactionUpdate(result)
        }
        Logger.warning("Transaction listener loop exited")
    }
    
        // Fix the deinit method to properly handle MainActor isolation
    deinit {
        // Since the class is @MainActor, we need to handle isolation boundary properly
        // Capture the task locally as a nonisolated copy
        let taskToCancel = Task { @MainActor in
            return _updates
        }
        
        // Create a detached task that cancels the original task
        Task.detached {
            // Await the task and cancel it if it exists
            if let updateTask = await taskToCancel.value {
                updateTask.cancel()
            }
        }
    }
    
    // Fetch current user's subscription info
    func getSubscriptionInfo() async throws -> SubscriptionInfo {
        // Always fetch fresh data from the server
        let subscription: SubscriptionInfo = try await APIClient.shared.get(endpoint: "/user/subscription")
        currentSubscription = subscription
        return subscription
    }
    
    // Check subscription status for a specific user
    func getUserSubscriptionStatus(userId: Int) async throws -> Bool {
        // Always fetch fresh data
        let response: UserSubscriptionStatus = try await APIClient.shared.get(endpoint: "/user/\(userId)/subscription/status")
        return response.isActive
    }
    
    // Batch check subscription status for multiple users
    func batchCheckSubscriptionStatus(userIds: [Int]) async -> [Int: Bool] {
        var results: [Int: Bool] = [:]
        await withTaskGroup(of: (Int, Bool?).self) { group in
            for userId in userIds {
                group.addTask {
                    if let status = try? await self.getUserSubscriptionStatus(userId: userId) {
                        return (userId, status)
                    }
                    return (userId, nil)
                }
            }
            
            for await (userId, status) in group {
                if let status = status {
                    results[userId] = status
                }
            }
        }
        return results
    }
    
    // Fetch available subscription products
    func fetchSubscriptionProducts() async throws -> [SubscriptionProduct] {
        Logger.info("Fetching subscription products from server")
        // Fetch products from server
        let endpoint = "/subscription/products?platform=apple"
        let apiProducts: [SubscriptionProduct] = try await APIClient.shared.get(endpoint: endpoint)
        
        Logger.info("Received \(apiProducts.count) products from server")
        // Log product details
        for product in apiProducts {
            Logger.info("Server product: id=\(product.id), productId=\(product.productId), name=\(product.name), tier=\(product.tier), type=\(product.type.rawValue)")
        }
        
        // Store the product IDs for StoreKit requests
        self.availableProducts = apiProducts
        
        // Request product info from StoreKit
        await loadStoreProducts()
        
        return availableProducts
    }
    
    // Fetch available scan pack products
    func fetchScanPackProducts() async throws -> [SubscriptionProduct] {
        Logger.info("Fetching scan pack products from server")
        // Fetch products from server
        let endpoint = "/subscription/products?platform=apple&type=scanpack"
        let apiProducts: [SubscriptionProduct] = try await APIClient.shared.get(endpoint: endpoint)
        
        Logger.info("Received \(apiProducts.count) scan pack products from server")
        // Log product details
        for product in apiProducts {
            Logger.info("Server product: id=\(product.id), productId=\(product.productId), name=\(product.name), scanCredits=\(product.scanCredits)")
        }
        
        // Merge with existing products or add them
        var updatedProducts = availableProducts.filter { $0.type != .scanpack }
        updatedProducts.append(contentsOf: apiProducts)
        self.availableProducts = updatedProducts
        
        // Request product info from StoreKit
        await loadStoreProducts()
        
        return apiProducts
    }
    
    // Load product information from App Store
    private func loadStoreProducts() async {
        do {
            // Get the StoreKit product IDs from our available products
            let productIDs = Set(availableProducts.map { $0.productId })
            
            Logger.info("Requesting products from StoreKit with IDs: \(productIDs.joined(separator: ", "))")
            Logger.info("Number of product IDs being requested: \(productIDs.count)")
            
            // Request products from StoreKit
            let storeProducts = try await Product.products(for: productIDs)
            self.storeProducts = storeProducts
            
            Logger.info("Successfully loaded \(storeProducts.count) products from StoreKit")
            if storeProducts.isEmpty {
                Logger.warning("⚠️ StoreKit returned zero products - check product IDs and App Store Connect configuration")
            } else {
                // Log details of returned products
                for product in storeProducts {
                    Logger.info("Product returned: id=\(product.id), title=\(product.displayName)")
                }
                
                // Log any missing products
                let returnedIDs = Set(storeProducts.map { $0.id })
                let missingIDs = productIDs.subtracting(returnedIDs)
                if (!missingIDs.isEmpty) {
                    Logger.warning("⚠️ Missing products from StoreKit: \(missingIDs.joined(separator: ", "))")
                }
            }
            
            // Update our available products with the StoreKit Product information
            for i in 0..<availableProducts.count {
                if let storeProduct = storeProducts.first(where: { $0.id == availableProducts[i].productId }) {
                    availableProducts[i].storeProduct = storeProduct
                    Logger.info("Matched product ID \(availableProducts[i].productId) with StoreKit product")
                } else {
                    Logger.warning("Could not find StoreKit product for ID: \(availableProducts[i].productId)")
                }
            }
        } catch {
            Logger.error("Failed to load products from StoreKit: \(error.localizedDescription)")
            Logger.error("Detailed error: \(String(describing: error))")
            self.error = error
        }
    }
    
    // Purchase a subscription
    func purchase(_ product: Product, retryCount: Int = 0, maxRetries: Int = 5) async throws -> SubscriptionInfo {
        // Determine if this is a scan pack or subscription purchase
        let isScanPack = availableProducts.first(where: { $0.productId == product.id })?.type == .scanpack
        
        Logger.info("Beginning purchase for \(isScanPack ? "scan pack" : "subscription") product: \(product.id)")
        Logger.info("Product details: displayName=\(product.displayName), description=\(product.description)")
        
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        
        do {
            Logger.info("Initiating StoreKit purchase")
            // Begin a purchase through StoreKit
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                Logger.info("Purchase result: success - verifying transaction")
                // Check if the transaction is verified
                switch verificationResult {
                case .verified(let transaction):
                    Logger.info("Transaction verified, ID: \(transaction.id)")
                    Logger.info("Transaction details: productID=\(transaction.productID), originalID=\(transaction.originalID)")
                    Logger.info("Transaction date: \(transaction.purchaseDate)")
                    
                    // Get the transaction data using the preferred approach
                    if isScanPack {
                        // Process as scan pack purchase
                        let purchaseRequest = ScanPackPurchaseRequest(
                            transactionId: transaction.id,
                            platform: "apple"
                        )
                        
                        Logger.info("Sending scan pack transaction to server for validation, transaction ID: \(transaction.id)")
                        
                        let response: ScanPackPurchaseResponse = try await APIClient.shared.post(
                            endpoint: "/scanpack/purchase",
                            body: purchaseRequest
                        )
                        
                        Logger.info("Server validation response received: success=\(response.success), message=\(response.message)")
                        
                        if let subscription = response.subscription, response.success {
                            Logger.info("Server validated scan pack transaction successfully")
                            // Finish the transaction
                            Logger.info("Finishing transaction in StoreKit")
                            await transaction.finish()
                            Logger.info("Transaction finished successfully")
                            
                            // Update local subscription info
                            Logger.info("Updating local subscription with new scan credits: \(subscription.scanCreditsRemaining)")
                            currentSubscription = subscription
                            return subscription
                        } else {
                            Logger.error("Server validation failed for scan pack: \(response.message)")
                            throw SubscriptionError.serverValidationFailed(message: response.message)
                        }
                    } else {
                        // Process as subscription purchase (existing code)
                        let purchaseRequest = SubscriptionPurchaseRequest(
                            transactionId: transaction.id,
                            platform: "apple"
                        )
                        
                        Logger.info("Sending subscription transaction to server for validation, transaction ID: \(transaction.id)")
                        
                        let response: SubscriptionPurchaseResponse = try await APIClient.shared.post(
                            endpoint: "/subscription/purchase",
                            body: purchaseRequest
                        )
                        
                        Logger.info("Server validation response received: success=\(response.success), message=\(response.message)")
                        
                        if let subscription = response.subscription, response.success {
                            Logger.info("Server validated transaction successfully")
                            // Finish the transaction
                            Logger.info("Finishing transaction in StoreKit")
                            await transaction.finish()
                            Logger.info("Transaction finished successfully")
                            
                            // Update local subscription info
                            Logger.info("Updating local subscription: tier=\(subscription.tier), expiry=\(subscription.subscriptionEnd?.description ?? "nil")")
                            currentSubscription = subscription
                            return subscription
                        } else {
                            Logger.error("Server validation failed: \(response.message)")
                            throw SubscriptionError.serverValidationFailed(message: response.message)
                        }
                    }
                    
                case .unverified(_, let verificationError):
                    Logger.error("Transaction unverified with error: \(verificationError.localizedDescription)")
                    Logger.error("Detailed verification error: \(String(describing: verificationError))")
                    throw SubscriptionError.unverifiedTransaction
                }
                
            case .userCancelled:
                Logger.info("Purchase cancelled by user")
                throw SubscriptionError.userCancelled
                
            case .pending:
                Logger.info("Purchase is pending approval")
                throw SubscriptionError.purchasePending
                
            @unknown default:
                Logger.error("Unknown purchase result state")
                throw SubscriptionError.unknown
            }
        } catch {
            Logger.error("Purchase failed with error: \(error.localizedDescription)")
            Logger.error("Detailed error: \(String(describing: error))")
            
            // Pass through StoreKit errors or wrap custom errors
            if let subError = error as? SubscriptionError {
                if retryCount < maxRetries {
                    
                    Logger.info("StoreKit connection failed, retrying (\(retryCount + 1)/\(maxRetries))...")
                    
                    // Wait briefly before retry (exponential backoff)
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                    
                    // Retry the purchase
                    return try await purchase(product, retryCount: retryCount + 1, maxRetries: maxRetries)
                }
        
                throw subError
            }
            throw SubscriptionError.storeKitError(error: error)
        }
    }
    
    // Check if current user has an active subscription
    var hasActiveSubscription: Bool {
        return currentSubscription?.isActive ?? false
    }
    
    // Get current subscription tier
    var currentTier: SubscriptionTier {
        return currentSubscription?.tier ?? .none
    }
    
    // Get remaining scan credits
    var scanCreditsRemaining: Int {
        return currentSubscription?.scanCreditsRemaining ?? 0
    }
    
    private static var processedTransactionIds = Set<UInt64>()

    private static func processTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Skip if we've already processed this transaction
            if processedTransactionIds.contains(transaction.id) {
                Logger.info("Skipping already processed transaction: \(transaction.id)")
                await transaction.finish()
                return
            }
            
            // Add to processed set
            processedTransactionIds.insert(transaction.id)
            
            Logger.info("Verified transaction detected in listener, ID: \(transaction.id)")
            Logger.info("Transaction details: productID=\(transaction.productID), purchaseDate=\(transaction.purchaseDate)")
            Logger.info("Transaction originalID: \(transaction.originalID), expirationDate: \(transaction.expirationDate?.description ?? "nil")")
            
            do {
                // Send the transaction ID to the server to validate and update subscription
                let purchaseRequest = SubscriptionPurchaseRequest(
                    transactionId: transaction.id,
                    platform: "apple"
                )
                
                Logger.info("Sending transaction to server from listener, transaction ID: \(transaction.id)")
                
                // Use the same endpoint as manual purchases
                let response: SubscriptionPurchaseResponse = try await APIClient.shared.post(
                    endpoint: "/subscription/purchase",
                    body: purchaseRequest
                )
                
                Logger.info("Server response received in listener: success=\(response.success), message=\(response.message)")
                
                if let updatedInfo = response.subscription, response.success {
                    await MainActor.run {
                        Logger.info("Updating subscription from listener: tier=\(updatedInfo.tier), expiry=\(updatedInfo.subscriptionEnd?.description ?? "nil")")
                        SubscriptionService.shared.currentSubscription = updatedInfo
                        Logger.info("Updated subscription info from transaction listener: \(updatedInfo.tier)")
                    }
                } else {
                    await MainActor.run {
                        Logger.error("Server validation failed in listener: \(response.message)")
                    }
                }
                
                // Always finish the transaction
                Logger.info("Finishing transaction in listener")
                await transaction.finish()
                Logger.info("Transaction finished in listener")
            } catch {
                await MainActor.run {
                    Logger.error("Failed to update subscription info in listener: \(error.localizedDescription)")
                    Logger.error("Detailed listener error: \(String(describing: error))")
                    
                    // Log network failure details if available
                    if let apiError = error as? APIError {
                        Logger.error("API Error in listener: \(apiError.localizedDescription)")
                        switch apiError {
                            case .invalidURL:
                                Logger.error("Invalid URL in listener")
                            case .httpError(let statusCode, let data):
                                Logger.error("Request failed in listener with status code: \(statusCode)")
                                if let data = data, let dataString = String(data: data, encoding: .utf8) {
                                    Logger.error("Response data: \(dataString)")
                                }
                            case .decoding(let decodingError):
                                Logger.error("Decoding failed in listener: \(decodingError.localizedDescription)")
                            case .network(let error):
                                Logger.error("Network error in listener: \(error.localizedDescription)")
                            // Include other cases as needed
                            case .invalidResponse:
                                Logger.error("Invalid response in listener")
                            case .maxRetriesExceeded:
                                Logger.error("Max retries exceeded in listener")
                            case .tokenExpired:
                                Logger.error("Token expired in listener")
                            case .unauthorized:
                                Logger.error("Unauthorized in listener")
                            case .paymentRequired(let message):
                                Logger.error("Payment required in listener: \(message)")
                        }
                    }
                }
                
                // Still finish the transaction to prevent it from being processed repeatedly
                Logger.info("Finishing transaction despite error in listener")
                await transaction.finish()
            }
            
        case .unverified(let transaction, let verificationError):
            Logger.error("Unverified transaction in listener, ID: \(transaction.id)")
            Logger.error("Verification error: \(verificationError.localizedDescription)")
            Logger.error("Detailed verification error: \(String(describing: verificationError))")
            
            // Still finish the transaction
            Logger.info("Finishing unverified transaction in listener")
            await transaction.finish()
        }
    }
    
    // Method kept for API compatibility
    func clearCache() {
        // No caching, so nothing to clear
    }
}

// Response type for user subscription status endpoint
struct UserSubscriptionStatus: Codable {
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
    }
}

// Custom errors for subscription operations
enum SubscriptionError: Error, LocalizedError {
    case noReceiptFound
    case serverValidationFailed(message: String)
    case unverifiedTransaction
    case userCancelled
    case purchasePending
    case storeKitError(error: Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noReceiptFound:
            return "Could not find App Store receipt"
        case .serverValidationFailed(let message):
            return "Server validation failed: \(message)"
        case .unverifiedTransaction:
            return "The transaction could not be verified"
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .storeKitError(let error):
            return "StoreKit error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
