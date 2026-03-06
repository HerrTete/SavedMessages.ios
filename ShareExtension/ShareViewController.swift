import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.HerrTete.SavedMessages"

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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        var items = loadItems(from: containerURL)
        let defaultTag = isURLString(text) ? "URL" : "Text"
        let newItem = SharedDataItem(
            id: UUID().uuidString, type: "text",
            title: String(text.prefix(50)), tags: [defaultTag],
            textContent: text,
            fileName: nil, mimeType: nil,
            createdAt: Date().timeIntervalSince1970)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func saveFileItem(url: URL) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let filesDir = containerURL.appendingPathComponent("Files")
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
        let type = itemType(forMimeType: mimeType, ext: ext)
        var items = loadItems(from: containerURL)
        let newItem = SharedDataItem(
            id: UUID().uuidString, type: type, title: origName,
            tags: [defaultTag(for: type)],
            textContent: nil, fileName: uniqueName, mimeType: mimeType,
            createdAt: Date().timeIntervalSince1970)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func saveDataItem(data: Data, name: String, mimeType: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let filesDir = containerURL.appendingPathComponent("Files")
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let ext = URL(fileURLWithPath: name).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)
        try? data.write(to: dest)

        let type = itemType(forMimeType: mimeType, ext: ext)
        var items = loadItems(from: containerURL)
        let newItem = SharedDataItem(
            id: UUID().uuidString, type: type, title: name,
            tags: [defaultTag(for: type)],
            textContent: nil, fileName: uniqueName, mimeType: mimeType,
            createdAt: Date().timeIntervalSince1970)
        items.insert(newItem, at: 0)
        saveItems(items, to: containerURL)
    }

    private func loadItems(from containerURL: URL) -> [SharedDataItem] {
        let url = containerURL.appendingPathComponent("items.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SharedDataItem].self, from: data)) ?? []
    }

    private func saveItems(_ items: [SharedDataItem], to containerURL: URL) {
        let url = containerURL.appendingPathComponent("items.json")
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func isURLString(_ text: String) -> Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              let host = url.host(percentEncoded: false), !host.isEmpty else { return false }
        return true
    }

    private func defaultTag(for type: String) -> String {
        switch type {
        case "audio": return "Audio"
        case "image": return "Foto"
        case "video": return "Video"
        case "text": return "Text"
        default: return "Datei"
        }
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        if let utType = UTType(filenameExtension: ext) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    private func itemType(forMimeType mimeType: String, ext: String) -> String {
        if mimeType.hasPrefix("image/") { return "image" }
        if mimeType.hasPrefix("video/") { return "video" }
        if mimeType.hasPrefix("audio/") { return "audio" }
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp": return "image"
        case "mp4", "mov", "avi", "mkv", "m4v": return "video"
        case "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus": return "audio"
        default: return "file"
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

struct SharedDataItem: Codable {
    var id: String
    var type: String
    var title: String
    var tags: [String]
    var textContent: String?
    var fileName: String?
    var mimeType: String?
    var createdAt: TimeInterval
}
