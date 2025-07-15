import SwiftUI
import UIKit

struct ScanView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isScanning = false
    @State private var error: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showSourcePicker = false
    @State private var scannedCar: Car?
    @State private var showingCarDetail = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @Environment(AppState.self) private var appState
    
    private var isDevEnvironment: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Add subscription info card
                    SubscriptionInfoCard(subscription: appState.subscription, compact: true)
                        .padding(.horizontal)
                    
                    if let subscription = appState.subscription, subscription.scanCreditsRemaining <= 0 {
                        ScanCreditsView()
                        .padding(.horizontal)
                    } else if appState.subscription?.isActive != true {
                        // New subscription callout for users without active subscription
                        SubscriptionRequiredView(
                            title: "scan.subscription_required.title".localized,
                            message: "scan.subscription_required.message".localized,
                            icon: "sparkles.rectangle.stack"
                        )
                        .padding(.horizontal)
                        
                        // Still show scan functionality but with limited features messaging
                        scanningView
                    } else {
                        scanningView
                    }
                }
            }
            .navigationTitle("scan.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showImagePicker) {
                if imageSource == .camera {
                    ImagePickerLegacy(image: $selectedImage, sourceType: imageSource)
                } else {
                    ImagePicker { image in
                        selectedImage = image
                    }
                }
            }
            .alert("common.error".localized, isPresented: $showError) {
                Button("common.ok".localized) { 
                    error = nil
                    showError = false 
                }
            } message: {
                Text(error ?? "scan.error.unknown".localized)
            }
            .sheet(isPresented: $showingCarDetail) {
                if let car = scannedCar {
                    CarDetailView(car: car)
                }
            }
        }
    }
    
    // New private view to avoid code duplication
    private var scanningView: some View {
        VStack(spacing: 20) {
            if let selectedImage {
                PulsingImageView(image: selectedImage, isAnimating: isScanning)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                    .padding(40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 15, x: 0, y: 0)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            
            Button(action: { 
                if isDevEnvironment {
                    showSourcePicker = true
                } else {
                    // In production, always use camera
                    imageSource = .camera
                    showImagePicker = true
                }
            }) {
                Label(selectedImage != nil ? "scan.change_photo".localized : "scan.car".localized, 
                      systemImage: selectedImage != nil ? "photo.on.rectangle" : "camera.fill")
                    .frame(width: 200)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white)
            }
            .confirmationDialog("scan.photo_source".localized, isPresented: $showSourcePicker) {
                Button("scan.source.camera".localized) {
                    imageSource = .camera
                    showImagePicker = true
                }
                
                // Only show photo library option in development builds
                if isDevEnvironment {
                    Button("scan.source.photo_library".localized) {
                        imageSource = .photoLibrary
                        showImagePicker = true
                    }
                }
                
                Button("common.cancel".localized, role: .cancel) {}
            }
            
            if let selectedImage {
                Button(action: scanCar) {
                    Group {
                        if isScanning {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("scan.analyzing".localized)
                                    .padding(.leading, 8)
                            }
                        } else {
                            Label("scan.identify".localized, systemImage: "sparkles.rectangle.stack")
                        }
                    }
                    .frame(width: 200)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isScanning ? Color.gray : Color.accentColor)
                            .shadow(color: (isScanning ? Color.gray : Color.accentColor).opacity(0.3), 
                                  radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
                .disabled(isScanning)
                .animation(.easeInOut, value: isScanning)
            }
        }
    }
    
    private func scanCar() {
        guard let image = selectedImage,
              let subscription = appState.subscription,
              subscription.scanCreditsRemaining > 0 else { return }
        
        isScanning = true
        Task {
            do {
                let car = try await ScanService.shared.scanCar(image: image)
                await appState.refreshSubscription() // Refresh credits after scan
                await MainActor.run {
                    isScanning = false
                    scannedCar = car
                    showingCarDetail = true
                    selectedImage = nil  // Clear the image after detail view is shown
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case .httpError(403, _):
                        error = "scan.error.no_credits".localized
                    case .httpError(409, _):
                        error = "scan.error.already_scanned".localized
                    case .httpError(400, let data):
                        if let data = data,
                           let errorResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                            error = errorResponse["error"]
                        } else {
                            error = "scan.error.invalid_image".localized
                        }
                    default:
                        error = "scan.error.failed".localized
                    }
                    showError = true
                    isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    showError = true
                    isScanning = false
                }
            }
        }
    }
}

// Legacy ImagePicker for camera support since PHPicker doesn't support camera
struct ImagePickerLegacy: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerLegacy
        
        init(_ parent: ImagePickerLegacy) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
