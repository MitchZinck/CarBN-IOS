import Foundation

struct SubscriptionInfo: Codable {
    let isActive: Bool
    let tier: SubscriptionTier
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    var scanCreditsRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case tier
        case subscriptionStart = "subscription_start"
        case subscriptionEnd = "subscription_end"
        case scanCreditsRemaining = "scan_credits_remaining"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decode(SubscriptionTier.self, forKey: .tier)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        scanCreditsRemaining = try container.decode(Int.self, forKey: .scanCreditsRemaining)
        
        // Handle TIMESTAMPTZ dates
        if let startDateString = try container.decodeIfPresent(String.self, forKey: .subscriptionStart),
           let date = startDateString.toDate() {
            subscriptionStart = date
        } else {
            subscriptionStart = nil
        }
        
        if let endDateString = try container.decodeIfPresent(String.self, forKey: .subscriptionEnd),
           let date = endDateString.toDate() {
            subscriptionEnd = date
        } else {
            subscriptionEnd = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(scanCreditsRemaining, forKey: .scanCreditsRemaining)
        
        if let start = subscriptionStart {
            try container.encode(start.rfc3339String(), forKey: .subscriptionStart)
        }
        
        if let end = subscriptionEnd {
            try container.encode(end.rfc3339String(), forKey: .subscriptionEnd)
        }
    }
}

enum SubscriptionTier: String, Codable {
    case none = "none"
    case basic = "basic"
    case standard = "standard"
    case premium = "premium"
    
    var scanCredits: Int {
        switch self {
        case .none:
            return 6
        case .basic:
            return 30
        case .standard:
            return 60
        case .premium:
            return 100
        }
    }
}
