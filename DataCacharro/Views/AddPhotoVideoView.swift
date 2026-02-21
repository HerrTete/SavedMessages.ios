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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
        }
    }

    private func saveSelectedItems() async {
        isProcessing = true
        loadFailedCount = 0
        for pickerItem in selectedItems {
            guard let data = try? await pickerItem.loadTransferable(type: Data.self) else {
                loadFailedCount += 1
                continue
            }
            let contentType = pickerItem.supportedContentTypes.first
            let mimeType = contentType?.preferredMIMEType ?? "image/jpeg"
            let ext = contentType?.preferredFilenameExtension ?? "jpg"
            let name = "\(UUID().uuidString).\(ext)"
            storage.addFileItem(data: data, fileName: name, mimeType: mimeType)
        }
        isProcessing = false
        if loadFailedCount > 0 {
            showingLoadError = true
        } else {
            dismiss()
        }
    }
}
