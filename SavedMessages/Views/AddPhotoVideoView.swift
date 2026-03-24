import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddPhotoVideoView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var loadFailedCount = 0
    @State private var showingLoadError = false
    @State private var showingCamera = false
    @State private var didCapture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Button {
                    showingCamera = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        Text("Take Photo or Video")
                            .font(.title3)
                        Text("Capture with your camera")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        Text("Select Photos & Videos")
                            .font(.title3)
                        Text("Tap to choose from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if !selectedItems.isEmpty {
                    Text("\(selectedItems.count) item(s) selected")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if isProcessing {
                    ProgressView("Saving…")
                        .padding()
                }
            }
            .navigationTitle("Photos & Videos")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Some Items Could Not Be Loaded", isPresented: $showingLoadError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(loadFailedCount) item(s) could not be imported.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveSelectedItems() }
                    }
                    .disabled(selectedItems.isEmpty || isProcessing)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPickerView { data, name, mimeType in
                    storage.addFileItem(data: data, fileName: name, mimeType: mimeType)
                    didCapture = true
                }
                .ignoresSafeArea()
            }
            .onChange(of: showingCamera) {
                if !showingCamera && didCapture {
                    dismiss()
                }
            }
        }
    }

    @MainActor
    private func saveSelectedItems() async {
        isProcessing = true
        loadFailedCount = 0
        for pickerItem in selectedItems {
            let contentType = pickerItem.supportedContentTypes.first
            let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
            let ext = contentType?.preferredFilenameExtension ?? "bin"
            let name = "\(UUID().uuidString).\(ext)"

            // Try direct Data loading first (reliable for images)
            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                storage.addFileItem(data: data, fileName: name, mimeType: mimeType)
                continue
            }

            // Fallback: use file representation via the item provider.
            // This is needed for videos and other large media that can't
            // be loaded as raw Data through the Transferable protocol.
            guard let typeID = contentType?.identifier else {
                loadFailedCount += 1
                continue
            }

            let fileData: Data? = await withCheckedContinuation { continuation in
                pickerItem.itemProvider.loadFileRepresentation(forTypeIdentifier: typeID) { url, error in
                    guard let url = url, let data = try? Data(contentsOf: url) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: data)
                }
            }

            if let fileData = fileData {
                storage.addFileItem(data: fileData, fileName: name, mimeType: mimeType)
            } else {
                loadFailedCount += 1
            }
        }
        isProcessing = false
        if loadFailedCount > 0 {
            showingLoadError = true
        } else {
            dismiss()
        }
    }
}
