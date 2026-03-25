import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - Pending items (collected from all providers, saved once at the end)

    private var pendingItems: [DataItem] = []
    private let itemsLock = NSLock()

    // MARK: - HUD UI

    private let hudContainer = UIView()
    private let iconView = UIImageView()
    private let statusLabel = UILabel()
    private var spinner: UIActivityIndicatorView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHUD()
        processSharedItems()
    }

    // MARK: - HUD Setup

    private func setupHUD() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.15)

        hudContainer.backgroundColor = .systemBackground
        hudContainer.layer.cornerRadius = 16
        hudContainer.layer.shadowColor = UIColor.black.cgColor
        hudContainer.layer.shadowOpacity = 0.15
        hudContainer.layer.shadowRadius = 10
        hudContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudContainer)

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        hudContainer.addSubview(activityIndicator)
        spinner = activityIndicator

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isHidden = true
        hudContainer.addSubview(iconView)

        statusLabel.text = "Saving…"
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        hudContainer.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            hudContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hudContainer.widthAnchor.constraint(equalToConstant: 160),
            hudContainer.heightAnchor.constraint(equalToConstant: 130),

            activityIndicator.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 24),

            iconView.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -8),
        ])
    }

    private func showResult(success: Bool, count: Int) {
        spinner?.stopAnimating()
        spinner?.isHidden = true
        iconView.isHidden = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        if success {
            iconView.tintColor = .systemGreen
            iconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolConfig)
            statusLabel.text = count == 1 ? "Saved" : "\(count) items saved"
        } else {
            iconView.tintColor = .systemRed
            iconView.image = UIImage(systemName: "xmark.circle.fill", withConfiguration: symbolConfig)
            statusLabel.text = "Error"
        }

        let hudDismissDelay: TimeInterval = 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + hudDismissDelay) {
            self.completeRequest()
        }
    }

    // MARK: - Processing

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showResult(success: false, count: 0)
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
            self.itemsLock.lock()
            let collected = self.pendingItems.count
            self.itemsLock.unlock()

            guard collected > 0 else {
                self.showResult(success: false, count: 0)
                return
            }

            self.showTagPicker()
        }
    }

    // MARK: - Tag picker

    private func showTagPicker() {
        spinner?.stopAnimating()
        spinner?.isHidden = true
        hudContainer.isHidden = true

        let tags = loadExistingTags()
        let tagView = ShareTagPickerView(existingTags: tags) { [weak self] selectedTags in
            guard let self else { return }
            self.applySelectedTags(selectedTags)
            self.dismiss(animated: true) {
                DispatchQueue.main.async {
                    let success = self.commitPendingItems()
                    self.itemsLock.lock()
                    let count = self.pendingItems.count
                    self.itemsLock.unlock()
                    self.hudContainer.isHidden = false
                    self.showResult(success: success, count: count)
                }
            }
        } onCancel: { [weak self] in
            self?.dismiss(animated: true) {
                self?.completeRequest()
            }
        }

        let hostingController = UIHostingController(rootView: tagView)
        hostingController.isModalInPresentation = true
        present(hostingController, animated: true)
    }

    private func applySelectedTags(_ selectedTags: Set<String>) {
        guard !selectedTags.isEmpty else { return }
        itemsLock.lock()
        for i in 0..<pendingItems.count {
            let newTags = selectedTags.filter { !pendingItems[i].tags.contains($0) }
            pendingItems[i].tags.append(contentsOf: newTags.sorted())
        }
        itemsLock.unlock()
    }

    private func loadExistingTags() -> [String] {
        guard let url = StorageConstants.itemsFileURL,
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([DataItem].self, from: data) else { return [] }
        return Array(Set(items.flatMap { $0.tags })).sorted()
    }

    // MARK: - Provider handling

    private func processProvider(_ provider: NSItemProvider, completion: @escaping () -> Void) {
        // Check specific media types first to avoid the greedy plainText match.
        // Many providers (e.g. images shared from Safari) conform to both
        // public.plain-text and public.image; checking text first would lose the file.
        let mediaTypes = [UTType.image.identifier, UTType.movie.identifier,
                          UTType.audio.identifier]
        for typeID in mediaTypes {
            if provider.hasItemConformingToTypeIdentifier(typeID) {
                provider.loadItem(forTypeIdentifier: typeID) { item, _ in
                    if let url = item as? URL {
                        if let dataItem = self.copyFileToContainer(url: url) {
                            self.addPendingItem(dataItem)
                        }
                    } else if let data = item as? Data {
                        let name = provider.suggestedName ?? "file"
                        let mimeType = UTType(typeID)?.preferredMIMEType ?? "application/octet-stream"
                        if let dataItem = self.writeDataToContainer(data: data, name: name, mimeType: mimeType) {
                            self.addPendingItem(dataItem)
                        }
                    } else if let image = item as? UIImage {
                        let name = provider.suggestedName ?? "image"
                        if let jpegData = image.jpegData(compressionQuality: 0.9) {
                            if let dataItem = self.writeDataToContainer(data: jpegData, name: name + ".jpg", mimeType: "image/jpeg") {
                                self.addPendingItem(dataItem)
                            }
                        } else if let pngData = image.pngData() {
                            if let dataItem = self.writeDataToContainer(data: pngData, name: name + ".png", mimeType: "image/png") {
                                self.addPendingItem(dataItem)
                            }
                        }
                    }
                    completion()
                }
                return
            }
        }

        // File URLs (e.g. PDFs, documents shared from Files app)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let url = item as? URL,
                   let dataItem = self.copyFileToContainer(url: url) {
                    self.addPendingItem(dataItem)
                }
                completion()
            }
            return
        }

        // Web URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL {
                    if url.isFileURL {
                        if let dataItem = self.copyFileToContainer(url: url) {
                            self.addPendingItem(dataItem)
                        }
                    } else {
                        self.addPendingItem(self.makeTextItem(text: url.absoluteString))
                    }
                }
                completion()
            }
            return
        }

        // Plain text before generic data, because plainText conforms to
        // UTType.data — checking data first would swallow text shares.
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                var text: String?
                if let t = item as? String {
                    text = t
                } else if let url = item as? URL {
                    text = url.absoluteString
                } else if let data = item as? Data {
                    text = String(data: data, encoding: .utf8)
                }
                if let text = text {
                    self.addPendingItem(self.makeTextItem(text: text))
                }
                completion()
            }
            return
        }

        // Generic data / files that didn't match any specific type above
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.data.identifier) { item, _ in
                if let url = item as? URL {
                    if let dataItem = self.copyFileToContainer(url: url) {
                        self.addPendingItem(dataItem)
                    }
                } else if let data = item as? Data {
                    let name = provider.suggestedName ?? "file"
                    if let dataItem = self.writeDataToContainer(data: data, name: name, mimeType: "application/octet-stream") {
                        self.addPendingItem(dataItem)
                    }
                }
                completion()
            }
            return
        }

        completion()
    }

    // MARK: - Item helpers

    private func addPendingItem(_ item: DataItem) {
        itemsLock.lock()
        pendingItems.append(item)
        itemsLock.unlock()
    }

    private func makeTextItem(text: String) -> DataItem {
        let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
        return DataItem(type: .text, title: String(text.prefix(50)), tags: [tag], textContent: text)
    }

    // MARK: - File operations

    private func copyFileToContainer(url: URL) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else { return nil }
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
            return nil
        }

        let mimeType = mimeTypeForExtension(ext)
        let type = DataItemType(mimeType: mimeType, fileName: origName)
        return DataItem(type: type, title: origName, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
    }

    private func writeDataToContainer(data: Data, name: String, mimeType: String) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else { return nil }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let ext = URL(fileURLWithPath: name).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)

        do {
            try data.write(to: dest)
        } catch {
            return nil
        }

        let type = DataItemType(mimeType: mimeType, fileName: name)
        return DataItem(type: type, title: name, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
    }

    // MARK: - Persistence (single atomic save of all collected items)

    private func commitPendingItems() -> Bool {
        guard let containerURL = StorageConstants.appGroupURL else { return false }
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)

        var existing: [DataItem] = []
        let fileManager = FileManager.default

        // Use NSFileCoordinator so the main app process sees the update
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var writeSuccess = false

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            if fileManager.fileExists(atPath: coordinatedURL.path) {
                do {
                    let data = try Data(contentsOf: coordinatedURL)
                    existing = try JSONDecoder().decode([DataItem].self, from: data)
                } catch {
                    return
                }
            }

            self.itemsLock.lock()
            let newItems = self.pendingItems
            self.itemsLock.unlock()

            guard !newItems.isEmpty else { return }

            existing.insert(contentsOf: newItems, at: 0)

            guard let encoded = try? JSONEncoder().encode(existing) else { return }
            do {
                try encoded.write(to: coordinatedURL, options: .atomic)
                writeSuccess = true
            } catch {
                return
            }
        }

        guard coordError == nil, writeSuccess else { return false }
        notifyMainApp()
        return true
    }

    // MARK: - Cross-process notification

    private func notifyMainApp() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(StorageConstants.itemsChangedNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    // MARK: - Helpers

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
