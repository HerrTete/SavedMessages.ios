import SwiftUI

@main
struct DataCacharroApp: App {
    @StateObject private var storage = StorageService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
        }
    }
}
