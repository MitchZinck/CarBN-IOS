import Foundation
import StoreKit

struct SubscriptionProduct: Codable, Identifiable {
    let id: Int
    let productId: String
    let name: String
    let tier: SubscriptionTier
    let platform: String
    let durationDays: Int
    let scanCredits: Int
    let type: ProductType
    
    // Local property to store the StoreKit Product object
    var storeProduct: Product?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case name
        case tier
        case platform
        case durationDays = "duration_days"
        case scanCredits = "scan_credits"
        case type
    }
}

enum ProductType: String, Codable {
    case subscription
    case scanpack
    
    // Default to subscription for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = ProductType(rawValue: value) ?? .subscription
    }
}

struct SubscriptionPurchaseRequest: Codable {
    let transactionId: UInt64
    let platform: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case platform
    }

    init(transactionId: UInt64, platform: String) {
        self.transactionId = transactionId
        self.platform = platform
    }
}

struct SubscriptionPurchaseResponse: Codable {
    let success: Bool
    let message: String
    let subscription: SubscriptionInfo?
}

struct ScanPackPurchaseRequest: Codable {
    let transactionId: UInt64
    let platform: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case platform
    }
    
    init(transactionId: UInt64, platform: String) {
        self.transactionId = transactionId
        self.platform = platform
    }
}

struct ScanPackPurchaseResponse: Codable {
    let success: Bool
    let message: String
    let subscription: SubscriptionInfo?
}