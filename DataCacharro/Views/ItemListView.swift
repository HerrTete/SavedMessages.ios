import SwiftUI

struct ItemListView: View {
    @EnvironmentObject var storage: StorageService
    @State private var selectedItem: DataItem?

    var body: some View {
        List {
            ForEach(storage.items) { item in
                ItemRowView(item: item)
                    .onTapGesture {
                        selectedItem = item
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            storage.deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            shareItem(item)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            storage.deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
        .overlay {
            if storage.items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "tray",
                    description: Text("Share content from other apps or tap + to add text.")
                )
            }
        }
    }

    private func shareItem(_ item: DataItem) {
        var activityItems: [Any] = []
        if let text = item.textContent {
            activityItems.append(text)
        } else if let url = storage.fileURL(for: item) {
            activityItems.append(url)
        }
        guard !activityItems.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(vc, animated: true)
        }
    }
}

struct ItemRowView: View {
    let item: DataItem

    var body: some View {
        HStack(spacing: 12) {
            itemIcon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(2)
                    .font(.body)
                Text(item.createdDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item.type {
        case .text:
            Image(systemName: "text.quote")
                .font(.title2)
                .foregroundStyle(.blue)
        case .image:
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.green)
        case .video:
            Image(systemName: "video")
                .font(.title2)
                .foregroundStyle(.orange)
        case .audio:
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.purple)
        case .file:
            Image(systemName: "doc")
                .font(.title2)
                .foregroundStyle(.gray)
        }
    }
}
