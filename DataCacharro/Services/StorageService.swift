import Foundation
import UIKit

class StorageService: ObservableObject {
    static let shared = StorageService()

    @Published var items: [DataItem] = []

    private let appGroupID = "group.com.HerrTete.DataCacharro"
    private let iCloudContainerID = "iCloud.com.HerrTete.DataCacharro"
    private let itemsFileName = "items.json"

    private var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private var filesURL: URL? {
        appGroupURL?.appendingPathComponent("Files", isDirectory: true)
    }

    private var itemsFileURL: URL? {
        appGroupURL?.appendingPathComponent(itemsFileName)
    }

    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
            .appendingPathComponent("Documents")
    }

    init() {
        setupDirectories()
        loadItems()
    }

    private func setupDirectories() {
        guard let filesURL = filesURL else { return }
        try? FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
    }

    func loadItems() {
        guard let url = itemsFileURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([DataItem].self, from: data) {
            DispatchQueue.main.async {
                self.items = loaded.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func saveItems() {
        guard let url = itemsFileURL else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
        syncToiCloud()
    }

    func addTextItem(text: String, sourceApp: String? = nil) {
        let item = DataItem(type: .text, title: String(text.prefix(50)), textContent: text, sourceApp: sourceApp)
        items.insert(item, at: 0)
        saveItems()
    }

    @discardableResult
    func addFileItem(data: Data, fileName: String, mimeType: String, sourceApp: String? = nil) -> DataItem? {
        guard let filesURL = filesURL else { return nil }
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)
        do {
            try data.write(to: fileURL)
        } catch {
            return nil
        }
        let type = dataItemType(forMimeType: mimeType, fileName: fileName)
        let item = DataItem(type: type, title: fileName, fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp)
        items.insert(item, at: 0)
        saveItems()
        return item
    }

    func fileURL(for item: DataItem) -> URL? {
        guard let fileName = item.fileName, let filesURL = filesURL else { return nil }
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
        if let fileName = item.fileName, let filesURL = filesURL {
            try? FileManager.default.removeItem(at: filesURL.appendingPathComponent(fileName))
        }
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    private func dataItemType(forMimeType mimeType: String, fileName: String) -> DataItemType {
        if mimeType.hasPrefix("image/") { return .image }
        if mimeType.hasPrefix("video/") { return .video }
        if mimeType.hasPrefix("audio/") { return .audio }
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp": return .image
        case "mp4", "mov", "avi", "mkv", "m4v": return .video
        case "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus": return .audio
        default: return .file
        }
    }

    private func syncToiCloud() {
        // One-way sync: copies local App Group files to iCloud Documents container.
        // Does not handle conflict resolution or syncing from iCloud to local.
        DispatchQueue.global(qos: .background).async {
            guard let iCloudURL = self.iCloudURL else { return }
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            if let localItemsURL = self.itemsFileURL {
                let iCloudItemsURL = iCloudURL.appendingPathComponent(self.itemsFileName)
                try? FileManager.default.removeItem(at: iCloudItemsURL)
                try? FileManager.default.copyItem(at: localItemsURL, to: iCloudItemsURL)
            }
            if let localFilesURL = self.filesURL {
                let iCloudFilesURL = iCloudURL.appendingPathComponent("Files")
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
