import SwiftUI

struct ContentView: View {
    @EnvironmentObject var storage: StorageService
    @State private var showingAddText = false
    @State private var showingAddAudio = false
    @State private var showingAddPhotoVideo = false

    var body: some View {
        TabView {
            NavigationStack {
                ItemListView()
                    .navigationTitle("SavedMessages")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingAddAudio = true }) {
                                Image(systemName: "mic.badge.plus")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingAddPhotoVideo = true }) {
                                Image(systemName: "photo.badge.plus")
                            }
                        }
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
            .sheet(isPresented: $showingAddAudio) {
                AddAudioView()
            }
            .sheet(isPresented: $showingAddPhotoVideo) {
                AddPhotoVideoView()
            }
            .tabItem {
                Label("Items", systemImage: "list.bullet")
            }

            NavigationStack {
                TagsView()
                    .navigationTitle("Tags")
            }
            .tabItem {
                Label("Tags", systemImage: "tag")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
            storage.loadItems()
        }
    }
}
