import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// A Transferable wrapper that uses FileRepresentation so large media
/// (especially videos) are streamed from disk instead of loaded into memory.
private struct MediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

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
                .accessibilityIdentifier("cameraButton")

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
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveSelectedItems() }
                    }
                    .disabled(selectedItems.isEmpty || isProcessing)
                    .accessibilityIdentifier("saveButton")
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPickerView { data, name, mimeType in
                    storage.addFileItem(data: data, fileName: name, mimeType: mimeType, location: LocationService.shared.currentAddress)
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
        .onAppear {
            LocationService.shared.start()
        }
    }

    @MainActor
    private func saveSelectedItems() async {
        isProcessing = true
        loadFailedCount = 0
        let location = LocationService.shared.currentAddress
        for pickerItem in selectedItems {
            let contentType = pickerItem.supportedContentTypes.first
            let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
            let ext = contentType?.preferredFilenameExtension ?? "bin"
            let name = "\(UUID().uuidString).\(ext)"

            // Try direct Data loading first (reliable for images)
            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                storage.addFileItem(data: data, fileName: name, mimeType: mimeType, location: location)
                continue
            }

            // Fallback: use FileRepresentation-based Transferable so large
            // media (especially videos) are streamed from disk rather than
            // loaded into memory as raw Data.
            if let mediaFile = try? await pickerItem.loadTransferable(type: MediaFile.self) {
                let addedItem = await storage.addFileItem(from: mediaFile.url, mimeType: mimeType, location: location)
                if addedItem != nil {
                    try? FileManager.default.removeItem(at: mediaFile.url)
                } else {
                    loadFailedCount += 1
                }
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
