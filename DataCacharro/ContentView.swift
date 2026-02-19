import SwiftUI

struct ContentView: View {
    @EnvironmentObject var storage: StorageService
    @State private var showingAddText = false

    var body: some View {
        NavigationStack {
            ItemListView()
                .navigationTitle("DataCacharro")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddText = true }) {
                            Image(systemName: "text.badge.plus")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingAddText) {
            AddTextView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            storage.loadItems()
        }
    }
}
