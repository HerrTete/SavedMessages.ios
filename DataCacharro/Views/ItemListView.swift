import SwiftUI

struct ItemListView: View {
    @EnvironmentObject var storage: StorageService
    var filterTag: String? = nil
    @State private var selectedItem: DataItem?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    private var displayedItems: [DataItem] {
        if let tag = filterTag {
            return storage.items.filter { $0.tags.contains(tag) }
        }
        return storage.items
    }

    var body: some View {
        List {
            ForEach(displayedItems) { item in
                ItemRowView(item: item)
                    .onTapGesture {
                        if let url = item.url {
                            UIApplication.shared.open(url)
                        } else {
                            selectedItem = item
                        }
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
                            prepareShare(item)
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .overlay {
            if displayedItems.isEmpty {
                ContentUnavailableView(
                    filterTag != nil ? "No Items with this Tag" : "No Items",
                    systemImage: "tray",
                    description: Text(filterTag != nil ? "No items are tagged with \"\(filterTag!)\"." : "Share content from other apps or tap + to add text.")
                )
            }
        }
    }

    private func prepareShare(_ item: DataItem) {
        var items: [Any] = []
        if let text = item.textContent {
            items.append(text)
        } else if let url = storage.fileURL(for: item) {
            items.append(url)
        }
        guard !items.isEmpty else { return }
        shareItems = items
        showingShareSheet = true
    }
}

struct ItemRowView: View {
    let item: DataItem

    var body: some View {
        HStack(spacing: 12) {
            itemIcon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(2)
                    .font(.body)
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Text(item.createdDate, format: .dateTime)
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
            Image(systemName: item.url != nil ? "link" : "text.quote")
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
