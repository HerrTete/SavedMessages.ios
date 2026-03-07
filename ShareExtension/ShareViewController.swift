import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedItems()
    }

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        let group = DispatchGroup()

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }
            for provider in attachments {
                group.enter()
                processProvider(provider) {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.completeRequest()
        }
    }

    private func processProvider(_ provider: NSItemProvider, completion: @escaping () -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                if let text = item as? String {
                    self.saveTextItem(text: text)
                } else if let url = item as? URL {
                    self.saveTextItem(text: url.absoluteString)
                } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    self.saveTextItem(text: text)
                }
                completion()
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL {
                    if url.isFileURL {
                        self.saveFileItem(url: url)
                    } else {
                        self.saveTextItem(text: url.absoluteString)
                    }
                }
                completion()
            }
        } else {
            let fileTypes = [UTType.image.identifier, UTType.movie.identifier,
                             UTType.audio.identifier, UTType.data.identifier]
            var handled = false
            for typeID in fileTypes {
                if provider.hasItemConformingToTypeIdentifier(typeID) && !handled {
                    handled = true
                    provider.loadItem(forTypeIdentifier: typeID) { item, _ in
                        if let url = item as? URL {
                            self.saveFileItem(url: url)
                        } else if let data = item as? Data {
                            let name = provider.suggestedName ?? "file"
                            let mimeType = UTType(typeID)?.preferredMIMEType ?? "application/octet-stream"
                            self.saveDataItem(data: data, name: name, mimeType: mimeType)
                        }
                        completion()
                    }
                    return
                }
            }
            if !handled { completion() }
        }
    }

    private func saveTextItem(text: String) {
        guard let containerURL = StorageConstants.appGroupURL else { return }
        var items = loadItems(from: containerURL)
        let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
        let newItem = DataItem(type: .text, title: String(text.prefix(50)), tags: [tag], textContent: text)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func saveFileItem(url: URL) {
        guard let containerURL = StorageConstants.appGroupURL else { return }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let origName = url.lastPathComponent
        let ext = url.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)

        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: url, to: dest)
            } else {
                try FileManager.default.copyItem(at: url, to: dest)
            }
        } catch {
            return
        }

        let mimeType = mimeTypeForExtension(ext)
        let type = DataItemType(mimeType: mimeType, fileName: origName)
        var items = loadItems(from: containerURL)
        let newItem = DataItem(type: type, title: origName, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func saveDataItem(data: Data, name: String, mimeType: String) {
        guard let containerURL = StorageConstants.appGroupURL else { return }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let ext = URL(fileURLWithPath: name).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)
        try? data.write(to: dest)

        let type = DataItemType(mimeType: mimeType, fileName: name)
        var items = loadItems(from: containerURL)
        let newItem = DataItem(type: type, title: name, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func loadItems(from containerURL: URL) -> [DataItem] {
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DataItem].self, from: data)) ?? []
    }

    private func saveItems(_ items: [DataItem], to containerURL: URL) {
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        if let utType = UTType(filenameExtension: ext) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
