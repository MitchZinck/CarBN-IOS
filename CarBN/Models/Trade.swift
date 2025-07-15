import Foundation
import SwiftUI

enum TradeStatus: String, Codable {
    case pending
    case accepted
    case declined
    
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .declined:
            return .red
        }
    }
}

struct Trade: Identifiable, Codable {
    let id: Int
    let fromUserId: Int
    let toUserId: Int
    let status: TradeStatus
    let fromUserCarIds: [Int]
    let toUserCarIds: [Int]
    let createdAt: Date
    let tradedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "user_id_from"
        case toUserId = "user_id_to"
        case status
        case fromUserCarIds = "user_from_user_car_ids"
        case toUserCarIds = "user_to_user_car_ids"
        case createdAt = "created_at"
        case tradedAt = "traded_at"
    }
    
    init(id: Int, fromUserId: Int, toUserId: Int, status: TradeStatus, fromUserCarIds: [Int], toUserCarIds: [Int], createdAt: Date, tradedAt: Date?) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.fromUserCarIds = fromUserCarIds
        self.toUserCarIds = toUserCarIds
        self.createdAt = createdAt
        self.tradedAt = tradedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        fromUserId = try container.decode(Int.self, forKey: .fromUserId)
        toUserId = try container.decode(Int.self, forKey: .toUserId)
        status = try container.decode(TradeStatus.self, forKey: .status)
        fromUserCarIds = try container.decode([Int].self, forKey: .fromUserCarIds)
        toUserCarIds = try container.decode([Int].self, forKey: .toUserCarIds)
        
        // Handle date formats with more flexibility
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = createdAtString.toDate() {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match expected format")
        }
        
        if let tradedAtString = try container.decodeIfPresent(String.self, forKey: .tradedAt) {
            tradedAt = tradedAtString.toDate()
        } else {
            tradedAt = nil
        }
    }
    
    // Custom encode to ensure dates are encoded in the correct format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fromUserId, forKey: .fromUserId)
        try container.encode(toUserId, forKey: .toUserId)
        try container.encode(status, forKey: .status)
        try container.encode(fromUserCarIds, forKey: .fromUserCarIds)
        try container.encode(toUserCarIds, forKey: .toUserCarIds)
        try container.encode(createdAt.rfc3339String(), forKey: .createdAt)
        if let tradedAt = tradedAt {
            try container.encode(tradedAt.rfc3339String(), forKey: .tradedAt)
        }
    }
}

struct TradeHistoryResponse: Codable {
    let trades: [Trade]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case trades
        case totalCount = "total_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trades = try container.decodeIfPresent([Trade].self, forKey: .trades) ?? []
        totalCount = try container.decode(Int.self, forKey: .totalCount)
    }
}

struct TradeRequest: Codable {
    let userIdTo: Int
    let userFromCarIds: [Int]
    let userToCarIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case userIdTo = "user_id_to"
        case userFromCarIds = "user_from_user_car_ids"
        case userToCarIds = "user_to_user_car_ids"
    }
}

struct TradeResponse: Codable {
    let tradeId: Int
    let response: String
    
    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case response
    }
}
