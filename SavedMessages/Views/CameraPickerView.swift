import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data, String, String) -> Void

    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                let name = "\(UUID().uuidString).jpg"
                parent.onCapture(data, name, "image/jpeg")
            } else if let videoURL = info[.mediaURL] as? URL,
                      let data = try? Data(contentsOf: videoURL) {
                let ext = videoURL.pathExtension.lowercased()
                let name = "\(UUID().uuidString).\(ext)"
                let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "video/quicktime"
                parent.onCapture(data, name, mimeType)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
