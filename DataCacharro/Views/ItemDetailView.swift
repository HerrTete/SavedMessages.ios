import SwiftUI
import AVKit
import QuickLook

struct ItemDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingQuickLook = false
    @State private var quickLookURL: URL?
    @State private var showingEdit = false

    var currentItem: DataItem {
        storage.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentItem.type {
                case .text:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(currentItem.textContent ?? "")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let url = currentItem.url {
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    Label("Open in Browser", systemImage: "safari")
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.horizontal)
                            }
                        }
                    }
                case .image:
                    ImageDetailView(item: currentItem)
                case .video:
                    VideoDetailView(item: currentItem)
                case .audio:
                    AudioDetailView(item: currentItem)
                case .file:
                    FileDetailView(item: currentItem) { url in
                        quickLookURL = url
                        showingQuickLook = true
                    }
                }
            }
            .navigationTitle(currentItem.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEdit = true }) {
                        Image(systemName: "pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: share) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingQuickLook) {
            if let url = quickLookURL {
                QuickLookView(url: url)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: currentItem)
        }
    }

    private func share() {
        var items: [Any] = []
        if let text = currentItem.textContent {
            items.append(text)
        } else if let url = storage.fileURL(for: currentItem) {
            items.append(url)
        }
        shareItems = items
        showingShareSheet = true
    }
}

struct EditItemView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var customName: String
    @State private var tags: [String]
    @State private var tagInput = ""

    private var suggestions: [String] {
        let existing = storage.allTags
        let query = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return existing.filter { $0.lowercased().hasPrefix(query) && !tags.contains($0) }
    }

    init(item: DataItem) {
        self.item = item
        _customName = State(initialValue: item.customName ?? "")
        _tags = State(initialValue: item.tags)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(item.title, text: $customName)
                        .autocorrectionDisabled()
                }

                Section("Tags") {
                    if !tags.isEmpty {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Label(tag, systemImage: "tag")
                                Spacer()
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("Add tag…", text: $tagInput)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .onSubmit { addTagFromInput() }
                        if !tagInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: addTagFromInput) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !suggestions.isEmpty {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                guard !tags.contains(suggestion) else { return }
                                tags.append(suggestion)
                                tagInput = ""
                            } label: {
                                Label(suggestion, systemImage: "tag")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = customName.trimmingCharacters(in: .whitespaces)
                        var updated = item
                        updated.customName = trimmed.isEmpty ? nil : trimmed
                        updated.tags = tags
                        storage.updateItem(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTagFromInput() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        tagInput = ""
    }
}

struct ImageDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService

    var body: some View {
        if let url = storage.fileURL(for: item), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("Image not found", systemImage: "photo.slash")
        }
    }
}

struct VideoDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService

    var body: some View {
        if let url = storage.fileURL(for: item) {
            VideoPlayer(player: AVPlayer(url: url))
        } else {
            ContentUnavailableView("Video not found", systemImage: "video.slash")
        }
    }
}

struct AudioDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.purple)

            Text(item.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let url = storage.fileURL(for: item) {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
}

struct FileDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    let onOpenExternal: (URL) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.fill")
                .font(.system(size: 80))
                .foregroundStyle(.gray)

            Text(item.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let mimeType = item.mimeType {
                Text(mimeType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let url = storage.fileURL(for: item) {
                Button("Open in External App") {
                    onOpenExternal(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
