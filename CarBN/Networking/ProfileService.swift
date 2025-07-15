import UIKit

@MainActor
final class ProfileService {
    static let shared = ProfileService()
    private init() {}
    
    func uploadProfilePicture(_ image: UIImage) async throws {
        // Process image
        let processedImage = processImage(image)
        
        // Convert to base64
        guard let imageData = processedImage.jpegData(compressionQuality: 0.9),
              let base64String = String(data: imageData.base64EncodedData(), encoding: .utf8) else {
            throw APIError.invalidResponse
        }
        
        // Create request body
        let body = ["base64_image": base64String]
        
        // Make request using APIClient
        do {
            let _: EmptyResponse = try await APIClient.shared.post(
                endpoint: APIConstants.uploadProfilePicturePath,
                body: body
            )
            
            // Update local cache on success and fetch latest user details
            UserManager.shared.updateProfileImage(processedImage)
        } catch {
            throw error
        }
    }
    
    func updateDisplayName(_ name: String) async throws {
        let body = ["display_name": name]
        let _: EmptyResponse = try await APIClient.shared.post(endpoint: "/user/profile/display-name", body: body)
    }
    
    private func processImage(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: APIConstants.Image.profilePictureSize, height: APIConstants.Image.profilePictureSize)
        
        // Get dimensions from the CGImage to ensure we're working with pixels not points
        guard let cgImage = image.cgImage else { return image }
        
        // Calculate the square crop area (centered)
        let width = cgImage.width
        let height = cgImage.height
        let size = min(width, height)
        
        let x = (width - size) / 2
        let y = (height - size) / 2
        
        // Crop the image to square using pixel coordinates (not points)
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }
        
        // Create UIImage with cropped CGImage
        let croppedImage = UIImage(cgImage: croppedCGImage, 
                                   scale: image.scale, 
                                   orientation: image.imageOrientation)
        
        // Scale down to target size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
