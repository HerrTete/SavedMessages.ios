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

    var body: some View {
        NavigationStack {
            Group {
                switch item.type {
                case .text:
                    ScrollView {
                        Text(item.textContent ?? "")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .image:
                    ImageDetailView(item: item)
                case .video:
                    VideoDetailView(item: item)
                case .audio:
                    AudioDetailView(item: item)
                case .file:
                    FileDetailView(item: item) { url in
                        quickLookURL = url
                        showingQuickLook = true
                    }
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
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
    }

    private func share() {
        var items: [Any] = []
        if let text = item.textContent {
            items.append(text)
        } else if let url = storage.fileURL(for: item) {
            items.append(url)
        }
        shareItems = items
        showingShareSheet = true
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
