import Foundation
import UIKit

struct ScanRequest: Encodable {
    let base64Image: String
    
    enum CodingKeys: String, CodingKey {
        case base64Image = "base64_image"
    }
}

struct ScanResponse: Decodable {
    let carId: Int
    let userCarId: Int
    let generatedImageHigh: String
    let generatedImageLow: String
    let make: String
    let model: String
    let trim: String
    let year: String
    let color: String
    let horsepower: Int
    let drivetrainType: String
    let curbWeight: Double
    let price: Int
    let description: String
    let torque: String
    let topSpeed: String
    let acceleration: String
    let rarity: Int
    let engineType: String
    
    enum CodingKeys: String, CodingKey {
        case carId = "car_id"
        case userCarId = "user_car_id"
        case generatedImageHigh = "generated_image_high"
        case generatedImageLow = "generated_image_low"
        case make, model, trim, year, color, horsepower
        case drivetrainType = "drivetrain_type"
        case curbWeight = "curb_weight"
        case price, description, torque, topSpeed, acceleration, rarity
        case engineType = "engine_type"
    }
}

@MainActor
final class ScanService {
    static let shared = ScanService()
    private let endpoint = "/scan"
    
    func scanCar(image: UIImage) async throws -> Car {
        // Always fetch fresh subscription info
        let subscription = try await SubscriptionService.shared.getSubscriptionInfo()
        guard subscription.scanCreditsRemaining > 0 else {
            throw APIError.httpError(403, "No scan credits remaining".data(using: .utf8))
        }
        
        Logger.info("Starting car scan process with \(subscription.scanCreditsRemaining) credits remaining")
        let processedImage = processImage(image)
        guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            Logger.error("Failed to compress image data")
            throw APIError.invalidResponse
        }
        
        Logger.info("Image processed and compressed successfully")
        let base64Image = imageData.base64EncodedString()
        let request = ScanRequest(base64Image: base64Image)
        
        do {
            Logger.info("Sending scan request to server")
            let car: Car = try await APIClient.shared.post(
                endpoint: endpoint,
                body: request
            )
            
            Logger.info("Car scan successful - identified: \(car.year) \(car.make) \(car.model)")
            
            // Update in-memory car list in CarService
            var existingCars = CarService.shared.getLocalCars()
            existingCars.append(car)
            CarService.shared.setUserCars(existingCars)
            
            return car
        } catch {
            throw error
        }
    }
    
    private func processImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        
        // Check if resizing is needed
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            Logger.info("Image within size limits, no resizing needed")
            return image
        }
        
        Logger.info("Resizing image to fit \(maxDimension)x\(maxDimension) bounds")
        // Calculate new dimensions
        let widthRatio = maxDimension / size.width
        let heightRatio = maxDimension / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        Logger.info("Image successfully resized to \(Int(newSize.width))x\(Int(newSize.height))")
        return resizedImage
    }
}
