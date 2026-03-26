import Foundation
import UIKit

class StorageService: ObservableObject {
    static let shared = StorageService()

    @Published var items: [DataItem] = []

    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: StorageConstants.iCloudContainerID)?
            .appendingPathComponent("Documents")
    }

    init() {
        setupDirectories()
        loadItems()
        registerForShareExtensionNotifications()
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    private func registerForShareExtensionNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = StorageConstants.itemsChangedNotification as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center, observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let service = Unmanaged<StorageService>.fromOpaque(observer).takeUnretainedValue()
                service.loadItems()
            },
            name, nil, .deliverImmediately
        )
    }

    private func setupDirectories() {
        guard let filesURL = StorageConstants.filesURL else { return }
        try? FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
    }

    func loadItems() {
        guard let url = StorageConstants.itemsFileURL else { return }

        // Use NSFileCoordinator to read data written by the share extension
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var loadedItems: [DataItem]?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            guard let data = try? Data(contentsOf: coordinatedURL) else { return }
            loadedItems = try? JSONDecoder().decode([DataItem].self, from: data)
        }

        if let coordError = coordError {
            print("StorageService.loadItems coordination error: \(coordError)")
            // Fallback to uncoordinated read when coordination fails
            if let data = try? Data(contentsOf: url) {
                loadedItems = try? JSONDecoder().decode([DataItem].self, from: data)
            }
        }

        if let loaded = loadedItems {
            DispatchQueue.main.async {
                self.items = loaded.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func saveItems() {
        guard let url = StorageConstants.itemsFileURL else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }

        // Use NSFileCoordinator so the share extension sees the latest state
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var writeError: Error?
        var didWrite = false

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                didWrite = true
            } catch {
                writeError = error
            }
        }

        if let coordError = coordError {
            print("StorageService.saveItems coordination error: \(coordError)")
        }

        if let writeError = writeError {
            print("StorageService.saveItems write error: \(writeError)")
        }

        guard coordError == nil, didWrite else {
            return
        }
        syncToiCloud()
    }

    func addTextItem(text: String, sourceApp: String? = nil, location: String? = nil) {
        var tags = [isURLString(text) ? "URL" : DataItemType.text.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: .text, title: String(text.prefix(50)), tags: tags, textContent: text, sourceApp: sourceApp, location: location)
        items.insert(item, at: 0)
        saveItems()
    }

    @discardableResult
    func addFileItem(data: Data, fileName: String, mimeType: String, sourceApp: String? = nil, location: String? = nil) -> DataItem? {
        guard let filesURL = StorageConstants.filesURL else { return nil }
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)
        do {
            try data.write(to: fileURL)
        } catch {
            return nil
        }
        let type = DataItemType(mimeType: mimeType, fileName: fileName)
        var tags = [type.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: type, title: fileName, tags: tags, fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp, location: location)
        items.insert(item, at: 0)
        saveItems()
        return item
    }

    @discardableResult
    func addFileItem(from sourceURL: URL, mimeType: String, sourceApp: String? = nil, location: String? = nil) async -> DataItem? {
        guard let filesURL = StorageConstants.filesURL else { return nil }
        let ext = sourceURL.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)

        let copySucceeded: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: fileURL)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }

        guard copySucceeded else { return nil }

        let originalName = sourceURL.lastPathComponent
        let type = DataItemType(mimeType: mimeType, fileName: originalName)
        var tags = [type.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: type, title: originalName, tags: tags, fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp, location: location)

        await MainActor.run {
            self.items.insert(item, at: 0)
            self.saveItems()
        }
        return item
    }

    func fileURL(for item: DataItem) -> URL? {
        guard let fileName = item.fileName, let filesURL = StorageConstants.filesURL else { return nil }
        return filesURL.appendingPathComponent(fileName)
    }

    func updateItem(_ item: DataItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        saveItems()
    }

    var allTags: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }

    func deleteItem(_ item: DataItem) {
        if let fileName = item.fileName, let filesURL = StorageConstants.filesURL {
            try? FileManager.default.removeItem(at: filesURL.appendingPathComponent(fileName))
        }
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func deleteItems(ids: Set<String>) {
        let toDelete = items.filter { ids.contains($0.id) }
        for item in toDelete {
            if let fileName = item.fileName, let filesURL = StorageConstants.filesURL {
                try? FileManager.default.removeItem(at: filesURL.appendingPathComponent(fileName))
            }
        }
        items.removeAll { ids.contains($0.id) }
        saveItems()
    }

    private func syncToiCloud() {
        DispatchQueue.global(qos: .background).async {
            guard let iCloudURL = self.iCloudURL else { return }
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            if let localItemsURL = StorageConstants.itemsFileURL {
                let iCloudItemsURL = iCloudURL.appendingPathComponent(StorageConstants.itemsFileName)
                try? FileManager.default.removeItem(at: iCloudItemsURL)
                try? FileManager.default.copyItem(at: localItemsURL, to: iCloudItemsURL)
            }
            if let localFilesURL = StorageConstants.filesURL {
                let iCloudFilesURL = iCloudURL.appendingPathComponent(StorageConstants.filesDirectoryName)
                try? FileManager.default.createDirectory(at: iCloudFilesURL, withIntermediateDirectories: true)
                if let files = try? FileManager.default.contentsOfDirectory(atPath: localFilesURL.path) {
                    for file in files {
                        let src = localFilesURL.appendingPathComponent(file)
                        let dst = iCloudFilesURL.appendingPathComponent(file)
                        if !FileManager.default.fileExists(atPath: dst.path) {
                            try? FileManager.default.copyItem(at: src, to: dst)
                        }
                    }
                }
            }
        }
    }
}
