import SwiftUI

@main
struct SavedMessagesApp: App {
    @StateObject private var storage = StorageService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
                .onAppear { LocationService.shared.start() }
        }
    }
}
