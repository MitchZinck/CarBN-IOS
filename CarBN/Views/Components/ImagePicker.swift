import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    let image: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(image: image)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let image: (UIImage?) -> Void
        
        init(image: @escaping (UIImage?) -> Void) {
            self.image = image
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else {
                image(nil)
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    DispatchQueue.main.async {
                        self?.image(object as? UIImage)
                    }
                }
            }
        }
    }
}