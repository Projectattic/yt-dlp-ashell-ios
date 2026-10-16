import Foundation

enum MediaKind: String, Hashable {
    case video, audio
    var symbol: String { self == .video ? "film" : "music.note" }
    var label: String { self == .video ? "Video" : "Audio" }
}

/// One downloaded file plus whatever yt-dlp saved alongside it.
struct MediaItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let kind: MediaKind
    let title: String
    let channel: String?
    let duration: Double?
    let uploadDate: Date?
    let webpageURL: URL?
    let viewCount: Int?
    let summary: String?
    let thumbnailURL: URL?
    let metadataURL: URL?
    let fileSize: Int64?
    let dateAdded: Date

    var fileExtension: String { url.pathExtension.lowercased() }
    var stem: String { url.deletingPathExtension().lastPathComponent }
    var canSaveToPhotos: Bool { ["mp4", "m4v", "mov"].contains(fileExtension) }

    var durationText: String? {
        guard let duration, duration > 0 else { return nil }
        let total = Int(duration.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var sizeText: String? {
        fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }
}

/// The handful of fields we need from yt-dlp's `.info.json`.
struct InfoJSON: Decodable {
    var title: String?
    var channel: String?
    var uploader: String?
    var duration: Double?
    var uploadDate: String?
    var webpageURL: String?
    var viewCount: Int?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case title, channel, uploader, duration, description
        case uploadDate = "upload_date"
        case webpageURL = "webpage_url"
        case viewCount = "view_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        channel = try? c.decodeIfPresent(String.self, forKey: .channel)
        uploader = try? c.decodeIfPresent(String.self, forKey: .uploader)
        duration = try? c.decodeIfPresent(Double.self, forKey: .duration)
        uploadDate = try? c.decodeIfPresent(String.self, forKey: .uploadDate)
        webpageURL = try? c.decodeIfPresent(String.self, forKey: .webpageURL)
        viewCount = try? c.decodeIfPresent(Int.self, forKey: .viewCount)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
    }

    var uploadDateValue: Date? {
        guard let uploadDate else { return nil }
        return Self.dateFormatter.date(from: uploadDate)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    // info.json files can be large, so parsed results are cached by path + modification date.
    private final class Box { let info: InfoJSON; init(_ i: InfoJSON) { info = i } }
    private static let cache = NSCache<NSString, Box>()

    static func load(_ url: URL) -> InfoJSON? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(modified)" as NSString
        if let hit = cache.object(forKey: key) { return hit.info }
        guard let data = try? Data(contentsOf: url),
              let info = try? JSONDecoder().decode(InfoJSON.self, from: data) else { return nil }
        cache.setObject(Box(info), forKey: key)
        return info
    }
}
