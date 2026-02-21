import SwiftUI

struct TagsView: View {
    @EnvironmentObject var storage: StorageService

    private var tagsWithCounts: [(tag: String, count: Int)] {
        storage.allTags.map { tag in
            (tag: tag, count: storage.items.filter { $0.tags.contains(tag) }.count)
        }
    }

    var body: some View {
        List {
            ForEach(tagsWithCounts, id: \.tag) { entry in
                NavigationLink {
                    ItemListView(filterTag: entry.tag)
                        .navigationTitle(entry.tag)
                } label: {
                    HStack {
                        Label(entry.tag, systemImage: "tag")
                        Spacer()
                        Text("\(entry.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .overlay {
            if storage.allTags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag.slash",
                    description: Text("Add tags to your items to organize them.")
                )
            }
        }
    }
}
