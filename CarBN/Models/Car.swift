import Foundation

struct Car: Codable, Identifiable, Hashable {
    let id: Int
    let userCarId: Int?
    let userId: Int?
    let make: String
    let model: String
    let trim: String?
    let year: String
    let color: String
    let horsepower: Int?
    let torque: Int?
    let topSpeed: Int?
    let acceleration: Double?
    let engineType: String?
    let drivetrainType: String?
    let curbWeight: Double?
    let price: Int?
    let rarity: Int?
    let description: String?
    var lowResImage: String?
    var highResImage: String?
    let dateCollected: Date?
    let upgrades: [CarUpgrade]?
    var likesCount: Int = 0
    var isLikedByCurrentUser: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case userCarId = "user_car_id"
        case userId = "user_id"
        case make
        case model
        case trim
        case year
        case color
        case horsepower
        case torque
        case topSpeed = "top_speed"
        case acceleration
        case engineType = "engine_type"
        case drivetrainType = "drivetrain_type"
        case curbWeight = "curb_weight"
        case price
        case rarity
        case description
        case lowResImage = "low_res_image"
        case highResImage = "high_res_image"
        case dateCollected = "date_collected"
        case upgrades
        case likesCount = "likes_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userCarId = try container.decodeIfPresent(Int.self, forKey: .userCarId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        trim = try container.decodeIfPresent(String.self, forKey: .trim)
        year = try container.decode(String.self, forKey: .year)
        color = try container.decode(String.self, forKey: .color)
        horsepower = try container.decodeIfPresent(Int.self, forKey: .horsepower)
        torque = try container.decodeIfPresent(Int.self, forKey: .torque)
        topSpeed = try container.decodeIfPresent(Int.self, forKey: .topSpeed)
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration)
        engineType = try container.decodeIfPresent(String.self, forKey: .engineType)
        drivetrainType = try container.decodeIfPresent(String.self, forKey: .drivetrainType)
        curbWeight = try container.decodeIfPresent(Double.self, forKey: .curbWeight)
        price = try container.decodeIfPresent(Int.self, forKey: .price)
        rarity = try container.decodeIfPresent(Int.self, forKey: .rarity)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lowResImage = try container.decodeIfPresent(String.self, forKey: .lowResImage)
        highResImage = try container.decodeIfPresent(String.self, forKey: .highResImage)
        upgrades = try container.decodeIfPresent([CarUpgrade].self, forKey: .upgrades)
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        isLikedByCurrentUser = false
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateCollected) {
            dateCollected = dateString.toDate()
        } else {
            dateCollected = nil
        }
    }

    // Add regular initializer
    init(id: Int, userCarId: Int?, userId: Int?, make: String, model: String, trim: String?, year: String, color: String,
         horsepower: Int?, torque: Int?, topSpeed: Int?, acceleration: Double?, engineType: String?,
         drivetrainType: String?, curbWeight: Double?, price: Int?, rarity: Int?, description: String?,
         lowResImage: String?, highResImage: String?, dateCollected: Date?, upgrades: [CarUpgrade]?, likesCount: Int = 0, isLikedByCurrentUser: Bool = false) {
        self.id = id
        self.userCarId = userCarId
        self.userId = userId
        self.make = make
        self.model = model
        self.trim = trim
        self.year = year
        self.color = color
        self.horsepower = horsepower
        self.torque = torque
        self.topSpeed = topSpeed
        self.acceleration = acceleration
        self.engineType = engineType
        self.drivetrainType = drivetrainType
        self.curbWeight = curbWeight
        self.price = price
        self.rarity = rarity
        self.description = description
        self.lowResImage = lowResImage
        self.highResImage = highResImage
        self.dateCollected = dateCollected
        self.upgrades = upgrades
        self.likesCount = likesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }

    // Add encoding support for dates
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userCarId, forKey: .userCarId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(trim, forKey: .trim)
        try container.encode(year, forKey: .year)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(horsepower, forKey: .horsepower)
        try container.encodeIfPresent(torque, forKey: .torque)
        try container.encodeIfPresent(topSpeed, forKey: .topSpeed)
        try container.encodeIfPresent(acceleration, forKey: .acceleration)
        try container.encodeIfPresent(engineType, forKey: .engineType)
        try container.encodeIfPresent(drivetrainType, forKey: .drivetrainType)
        try container.encodeIfPresent(curbWeight, forKey: .curbWeight)
        try container.encodeIfPresent(price, forKey: .price)
        try container.encodeIfPresent(rarity, forKey: .rarity)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(lowResImage, forKey: .lowResImage)
        try container.encodeIfPresent(highResImage, forKey: .highResImage)
        try container.encodeIfPresent(upgrades, forKey: .upgrades)
        try container.encode(likesCount, forKey: .likesCount)
        if let dateCollected = dateCollected {
            try container.encode(dateCollected.rfc3339String(), forKey: .dateCollected)
        }
    }

    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(userCarId)
    }
    
    static func == (lhs: Car, rhs: Car) -> Bool {
        return lhs.userCarId == rhs.userCarId
    }
    
    var hasPremiumImage: Bool {
        return upgrades?.first(where: { $0.upgradeType == "premium_image" && $0.active })?.active ?? false
    }
    
    // Remove setPremiumImage since we're using immutable approach with copy methods
    
    func copy(
        withHighResImage highResImage: String? = nil,
        withLowResImage lowResImage: String? = nil,
        withUpgrades upgrades: [CarUpgrade]? = nil,
        withLikesCount likesCount: Int? = nil,
        withIsLikedByCurrentUser isLikedByCurrentUser: Bool? = nil
    ) -> Car {
        return Car(
            id: id,
            userCarId: userCarId,
            userId: userId,
            make: make,
            model: model,
            trim: trim,
            year: year,
            color: color,
            horsepower: horsepower,
            torque: torque,
            topSpeed: topSpeed,
            acceleration: acceleration,
            engineType: engineType,
            drivetrainType: drivetrainType,
            curbWeight: curbWeight,
            price: price,
            rarity: rarity,
            description: description,
            lowResImage: lowResImage ?? self.lowResImage,
            highResImage: highResImage ?? self.highResImage,
            dateCollected: dateCollected,
            upgrades: upgrades ?? self.upgrades,
            likesCount: likesCount ?? self.likesCount,
            isLikedByCurrentUser: isLikedByCurrentUser ?? self.isLikedByCurrentUser
        )
    }

    func withPremiumImage(active: Bool) -> Car {
        var newUpgrades = upgrades ?? []
        let now = Date()
        
        if let index = newUpgrades.firstIndex(where: { $0.upgradeType == "premium_image" }) {
            // Use the existing upgrade's ID and metadata, just update active status
            let existingUpgrade = newUpgrades[index]
            let newUpgrade = CarUpgrade(
                id: existingUpgrade.id,
                upgradeType: "premium_image",
                active: active,
                metadata: existingUpgrade.metadata,
                createdAt: existingUpgrade.createdAt,
                updatedAt: now
            )
            newUpgrades[index] = newUpgrade
        } else {
            // Create a new upgrade with a temporary ID (will be replaced by server)
            let newUpgrade = CarUpgrade(
                id: -1,
                upgradeType: "premium_image",
                active: active,
                metadata: nil,
                createdAt: now,
                updatedAt: now
            )
            newUpgrades.append(newUpgrade)
        }
        return copy(withUpgrades: newUpgrades)
    }
    
    var lowResImageURL: String {
        if let imagePath = lowResImage,
           let encodedPath = imagePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            return "\(APIConstants.baseURL)/images/\(encodedPath)"
        }
        return ""
    }

    var highResImageURL: String {
        if let imagePath = highResImage,
           let encodedPath = imagePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            return "\(APIConstants.baseURL)/images/\(encodedPath)"
        }
        return ""
    }
}

struct SellCarResponse: Codable {
    let message: String
    let currencyEarned: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case currencyEarned = "currency_earned"
    }
}

struct CarImageResponse: Codable {
    let message: String
    let remainingCurrency: Int?
    let highResImage: String?
    let lowResImage: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case remainingCurrency = "remaining_currency"
        case highResImage = "high_res_image"
        case lowResImage = "low_res_image"
    }
}
