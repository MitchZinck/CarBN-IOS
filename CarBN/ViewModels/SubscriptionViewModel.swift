import Foundation
import StoreKit
import SwiftUI

@MainActor
@Observable
class SubscriptionViewModel {
    private let subscriptionService = SubscriptionService.shared
    
    private(set) var subscriptionInfo: SubscriptionInfo?
    private(set) var subscriptionProducts: [SubscriptionProduct] = []
    private(set) var scanPackProducts: [SubscriptionProduct] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var purchaseSuccess = false
    
    // Initialize and load subscription info
    init() {
        Task {
            await loadSubscriptionInfo()
            await loadProducts()
        }
    }

    func setPurchaseSuccess(_ value: Bool) {
        purchaseSuccess = value
    }
    
    // Load user's subscription info
    func loadSubscriptionInfo() async {
        isLoading = true
        errorMessage = nil
        
        do {
            subscriptionInfo = try await subscriptionService.getSubscriptionInfo()
        } catch {
            errorMessage = "Failed to load subscription info: \(error.localizedDescription)"
            Logger.error(errorMessage ?? "Unknown error")
        }
        
        isLoading = false
    }
    
    // Load available subscription products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First load all subscription products (including scan packs)
            let allProducts = try await subscriptionService.fetchSubscriptionProducts()
            
            // Then fetch scan packs to ensure they're loaded in StoreKit
            _ = try await subscriptionService.fetchScanPackProducts()
            
            // Now get all products from the service which should have StoreKit info attached
            subscriptionProducts = subscriptionService.availableProducts.filter { $0.type != .scanpack }
            scanPackProducts = subscriptionService.availableProducts.filter { $0.type == .scanpack }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            Logger.error(errorMessage ?? "Unknown error")
        }
        
        isLoading = false
    }
    
    // Purchase a subscription
    func purchaseSubscription(product: SubscriptionProduct) async {
        guard let storeProduct = product.storeProduct else {
            errorMessage = "Store product not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        purchaseSuccess = false
        
        do {
            let updatedSubscription = try await subscriptionService.purchase(storeProduct)
            subscriptionInfo = updatedSubscription
            purchaseSuccess = true
        } catch {
            if let subError = error as? SubscriptionError {
                errorMessage = subError.errorDescription
            } else {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
            Logger.error(errorMessage ?? "Unknown error")
        }
        
        isLoading = false
    }
    
    // Purchase a scan pack
    func purchaseScanPack(product: SubscriptionProduct) async {
        guard let storeProduct = product.storeProduct else {
            errorMessage = "Store product not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        purchaseSuccess = false
        
        do {
            let updatedSubscription = try await subscriptionService.purchase(storeProduct)
            subscriptionInfo = updatedSubscription
            purchaseSuccess = true
        } catch {
            if let subError = error as? SubscriptionError {
                errorMessage = subError.errorDescription
            } else {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
            Logger.error(errorMessage ?? "Unknown error")
        }
        
        isLoading = false
    }
    
    // Refresh data
    func refresh() async {
        await loadSubscriptionInfo()
        await loadProducts()
    }
    
    // Check if user has active subscription
    var hasActiveSubscription: Bool {
        return subscriptionInfo?.isActive ?? false
    }
    
    // Get formatted subscription expiration date
    var formattedExpirationDate: String {
        guard let expirationDate = subscriptionInfo?.subscriptionEnd else {
            return "Not subscribed"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Expires: \(formatter.string(from: expirationDate))"
    }
    
    // Get current subscription tier display name
    var currentTierName: String {
        guard let tier = subscriptionInfo?.tier else {
            return "Not subscribed"
        }
        
        switch tier {
        case .none:
            return "Free"
        case .basic:
            return "Basic"
        case .standard:
            return "Standard"
        case .premium:
            return "Premium"
        }
    }
    
    // Check if a user can trade (requires subscription)
    func canTrade(withUserId userId: Int? = nil) async -> Bool {
        guard subscriptionInfo?.isActive == true else {
            return false
        }
        
        // If trading with another user, check their subscription status too
        if let userId = userId {
            do {
                return try await subscriptionService.getUserSubscriptionStatus(userId: userId)
            } catch {
                Logger.error("Failed to check user subscription status: \(error.localizedDescription)")
                return false
            }
        }
        
        return true
    }
    
    // Get remaining scan credits
    var scanCreditsRemaining: Int {
        return subscriptionInfo?.scanCreditsRemaining ?? 0
    }
}