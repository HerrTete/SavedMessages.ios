import Foundation

enum DataItemType: String, Codable {
    case text, image, video, audio, file
}

struct DataItem: Identifiable, Codable {
    var id: String
    var type: DataItemType
    var title: String
    var customName: String?
    var tags: [String]
    var textContent: String?
    var fileName: String?
    var mimeType: String?
    var createdAt: TimeInterval
    var sourceApp: String?

    init(id: String = UUID().uuidString, type: DataItemType, title: String,
         customName: String? = nil, tags: [String] = [],
         textContent: String? = nil, fileName: String? = nil, mimeType: String? = nil,
         createdAt: TimeInterval = Date().timeIntervalSince1970, sourceApp: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.customName = customName
        self.tags = tags
        self.textContent = textContent
        self.fileName = fileName
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.sourceApp = sourceApp
    }

    var displayName: String { customName.flatMap { $0.isEmpty ? nil : $0 } ?? title }

    var createdDate: Date { Date(timeIntervalSince1970: createdAt) }

    var url: URL? {
        guard type == .text, let text = textContent,
              let url = URL(string: text),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        return url
    }
}
