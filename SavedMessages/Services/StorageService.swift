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
    }

    private func setupDirectories() {
        guard let filesURL = StorageConstants.filesURL else { return }
        try? FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
    }

    func loadItems() {
        guard let url = StorageConstants.itemsFileURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([DataItem].self, from: data) {
            DispatchQueue.main.async {
                self.items = loaded.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func saveItems() {
        guard let url = StorageConstants.itemsFileURL else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
        syncToiCloud()
    }

    func addTextItem(text: String, sourceApp: String? = nil) {
        let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
        let item = DataItem(type: .text, title: String(text.prefix(50)), tags: [tag], textContent: text, sourceApp: sourceApp)
        items.insert(item, at: 0)
        saveItems()
    }

    @discardableResult
    func addFileItem(data: Data, fileName: String, mimeType: String, sourceApp: String? = nil) -> DataItem? {
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
        let item = DataItem(type: type, title: fileName, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp)
        items.insert(item, at: 0)
        saveItems()
        return item
    }

    @discardableResult
    func addFileItem(from sourceURL: URL, mimeType: String, sourceApp: String? = nil) -> DataItem? {
        guard let filesURL = StorageConstants.filesURL else { return nil }
        let ext = sourceURL.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: fileURL)
        } catch {
            return nil
        }
        let originalName = sourceURL.lastPathComponent
        let type = DataItemType(mimeType: mimeType, fileName: originalName)
        let item = DataItem(type: type, title: originalName, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp)
        items.insert(item, at: 0)
        saveItems()
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
