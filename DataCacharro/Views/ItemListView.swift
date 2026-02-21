import SwiftUI

struct ItemListView: View {
    @EnvironmentObject var storage: StorageService
    @State private var selectedItem: DataItem?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    private var groupedItems: [(key: Date, items: [DataItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: storage.items) { item in
            calendar.startOfDay(for: item.createdDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    var body: some View {
        List {
            ForEach(storage.items) { item in
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
            if storage.items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "tray",
                    description: Text("Share content from other apps or tap + to add text.")
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

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
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
