import Foundation

extension DataItemType {
    var defaultTag: String {
        switch self {
        case .audio: return "Audio"
        case .image: return "Foto"
        case .video: return "Video"
        case .text:  return "Text"
        case .file:  return "Datei"
        }
    }

    init(mimeType: String, fileName: String) {
        if mimeType.hasPrefix("image/") { self = .image; return }
        if mimeType.hasPrefix("video/") { self = .video; return }
        if mimeType.hasPrefix("audio/") { self = .audio; return }
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp": self = .image
        case "mp4", "mov", "avi", "mkv", "m4v": self = .video
        case "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus": self = .audio
        default: self = .file
        }
    }
}

func isURLString(_ text: String) -> Bool {
    guard let url = URL(string: text),
          let scheme = url.scheme,
          (scheme == "http" || scheme == "https"),
          let host = url.host(percentEncoded: false), !host.isEmpty else { return false }
    return true
}
