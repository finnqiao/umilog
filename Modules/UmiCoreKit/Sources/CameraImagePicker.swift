import SwiftUI
import UIKit

public struct CameraImagePicker: UIViewControllerRepresentable {
    public let sourceType: UIImagePickerController.SourceType
    public var allowsEditing: Bool
    public let onImagePicked: (UIImage) -> Void
    public var onCancel: (() -> Void)?

    public init(
        sourceType: UIImagePickerController.SourceType = .camera,
        allowsEditing: Bool = false,
        onImagePicked: @escaping (UIImage) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.sourceType = sourceType
        self.allowsEditing = allowsEditing
        self.onImagePicked = onImagePicked
        self.onCancel = onCancel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: (() -> Void)?

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: (() -> Void)?) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onCancel?()
            }
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            picker.dismiss(animated: true) {
                if let image {
                    self.onImagePicked(image)
                } else {
                    self.onCancel?()
                }
            }
        }
    }
}
