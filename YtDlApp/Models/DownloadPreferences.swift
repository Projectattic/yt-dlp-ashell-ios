import Foundation
import Observation

// MARK: - Option enums

enum DownloadMode: String, Codable, CaseIterable, Identifiable {
    case video, audio
    var id: String { rawValue }
    var label: String { self == .video ? "Video" : "Audio" }
    var systemImage: String { self == .video ? "film" : "music.note" }
}

enum VideoQuality: String, Codable, CaseIterable, Identifiable {
    case best, p2160, p1440, p1080, p720, p480, p360
    var id: String { rawValue }

    var label: String {
        switch self {
        case .best: "Best available"
        case .p2160: "2160p (4K)"
        case .p1440: "1440p"
        case .p1080: "1080p"
        case .p720: "720p"
        case .p480: "480p"
        case .p360: "360p"
        }
    }

    var height: Int? {
        switch self {
        case .best: nil
        case .p2160: 2160
        case .p1440: 1440
        case .p1080: 1080
        case .p720: 720
        case .p480: 480
        case .p360: 360
        }
    }
}

enum VideoContainer: String, Codable, CaseIterable, Identifiable {
    case mp4, mkv, webm
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum AudioFormat: String, Codable, CaseIterable, Identifiable {
    case m4a, mp3, opus, flac, wav, best
    var id: String { rawValue }

    var label: String {
        switch self {
        case .m4a: "M4A (AAC)"
        case .mp3: "MP3"
        case .opus: "Opus"
        case .flac: "FLAC"
        case .wav: "WAV"
        case .best: "Original (no conversion)"
        }
    }

    /// Lossy formats accept an --audio-quality value.
    var isLossy: Bool { [.m4a, .mp3, .opus].contains(self) }
}

enum AudioQuality: String, Codable, CaseIterable, Identifiable {
    case best = "0", k320 = "320K", k256 = "256K", k192 = "192K", k128 = "128K"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .best: "Best (VBR)"
        case .k320: "320 kbps"
        case .k256: "256 kbps"
        case .k192: "192 kbps"
        case .k128: "128 kbps"
        }
    }
}

enum FilenameStyle: String, Codable, CaseIterable, Identifiable {
    case title, channelTitle, titleID, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Video title"
        case .channelTitle: "Channel – Title"
        case .titleID: "Title [video ID]"
        case .custom: "Custom template"
        }
    }

    var template: String {
        switch self {
        case .title, .custom: "%(title)s.%(ext)s"
        case .channelTitle: "%(channel,uploader)s - %(title)s.%(ext)s"
        case .titleID: "%(title)s [%(id)s].%(ext)s"
        }
    }
}

enum PlaylistHandling: String, Codable, CaseIterable, Identifiable {
    case single, full
    var id: String { rawValue }
    var label: String { self == .single ? "Only the linked video" : "Whole playlist" }
}

enum RunMethod: String, Codable, CaseIterable, Identifiable {
    case shortcut, clipboard
    var id: String { rawValue }
    var label: String { self == .shortcut ? "Shortcut" : "Copy & paste" }

    var footer: String {
        switch self {
        case .shortcut:
            "The app runs your Shortcut, which passes the command to a-Shell's “Execute Command” action. See the set-up guide."
        case .clipboard:
            "The command is copied and a-Shell is opened. Paste it and press return."
        }
    }
}

struct SponsorBlockCategory: Identifiable {
    let id: String
    let label: String

    static let all: [SponsorBlockCategory] = [
        .init(id: "sponsor", label: "Sponsors"),
        .init(id: "selfpromo", label: "Self-promotion"),
        .init(id: "interaction", label: "Like/subscribe reminders"),
        .init(id: "intro", label: "Intros"),
        .init(id: "outro", label: "Outros & end cards"),
        .init(id: "preview", label: "Previews & recaps"),
        .init(id: "music_offtopic", label: "Non-music sections"),
        .init(id: "filler", label: "Filler tangents"),
    ]
}

// MARK: - Preferences

struct DownloadPreferences: Codable, Equatable {
    // Format
    var mode: DownloadMode = .video
    var videoQuality: VideoQuality = .p1080
    var videoContainer: VideoContainer = .mp4
    var preferCompatibleCodecs = true
    var audioFormat: AudioFormat = .m4a
    var audioQuality: AudioQuality = .best

    // Files
    var outputFolder = "~/Documents/yt-dl"
    /// Name of an a-Shell bookmark (made with `pickFolder` + `bookmark NAME`) for a folder
    /// belonging to another app, e.g. VLC. When set, downloads go there instead of `outputFolder`.
    var folderBookmark = ""
    var filenameStyle: FilenameStyle = .title
    var customTemplate = "%(title)s.%(ext)s"
    var sidecarsInSubfolders = true
    var restrictFilenames = false

    // Thumbnails & metadata
    var writeThumbnail = true
    var embedThumbnail = true
    var writeInfoJSON = true
    var embedMetadata = true
    var channelAsArtist = true
    var channelAsAlbum = false
    var embedChapters = true

    // Subtitles
    var downloadSubtitles = false
    var autoSubtitles = false
    var subtitleLanguages = "en.*"

    // SponsorBlock
    var sponsorBlockRemove = false
    var sponsorBlockCategories: [String] = ["sponsor", "selfpromo", "interaction"]

    // Advanced
    var playlist: PlaylistHandling = .single
    var useDownloadArchive = false
    var rateLimit = ""
    var extraArguments = ""

    // a-Shell
    var runMethod: RunMethod = .shortcut
    var shortcutName = "yt-dlp"
    /// How yt-dlp is invoked in a-Shell. `python3 -m yt_dlp` avoids picking up
    /// stray `yt-dlp` launchers (e.g. from other Shortcuts' environments) on the PATH.
    var ytDlpCommand = DownloadPreferences.defaultYtDlpCommand
    /// Adds `open ytdlapp://finished` after yt-dlp so a-Shell switches back when done.
    var returnToAppWhenDone = true

    static let defaultYtDlpCommand = "python3 -m yt_dlp"
    static let updateCommand = "python3 -m pip install -U yt-dlp mutagen"

    var trimmedBookmark: String { folderBookmark.trimmingCharacters(in: .whitespaces) }

    /// Human description of where files end up.
    var destinationDescription: String {
        trimmedBookmark.isEmpty ? outputFolder : "the “\(trimmedBookmark)” bookmark in a-Shell"
    }

    init() {}

    /// Decodes leniently so settings saved by an older version keep working
    /// when new options are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DownloadPreferences()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        mode = v(.mode, d.mode)
        videoQuality = v(.videoQuality, d.videoQuality)
        videoContainer = v(.videoContainer, d.videoContainer)
        preferCompatibleCodecs = v(.preferCompatibleCodecs, d.preferCompatibleCodecs)
        audioFormat = v(.audioFormat, d.audioFormat)
        audioQuality = v(.audioQuality, d.audioQuality)
        outputFolder = v(.outputFolder, d.outputFolder)
        folderBookmark = v(.folderBookmark, d.folderBookmark)
        filenameStyle = v(.filenameStyle, d.filenameStyle)
        customTemplate = v(.customTemplate, d.customTemplate)
        sidecarsInSubfolders = v(.sidecarsInSubfolders, d.sidecarsInSubfolders)
        restrictFilenames = v(.restrictFilenames, d.restrictFilenames)
        writeThumbnail = v(.writeThumbnail, d.writeThumbnail)
        embedThumbnail = v(.embedThumbnail, d.embedThumbnail)
        writeInfoJSON = v(.writeInfoJSON, d.writeInfoJSON)
        embedMetadata = v(.embedMetadata, d.embedMetadata)
        channelAsArtist = v(.channelAsArtist, d.channelAsArtist)
        channelAsAlbum = v(.channelAsAlbum, d.channelAsAlbum)
        embedChapters = v(.embedChapters, d.embedChapters)
        downloadSubtitles = v(.downloadSubtitles, d.downloadSubtitles)
        autoSubtitles = v(.autoSubtitles, d.autoSubtitles)
        subtitleLanguages = v(.subtitleLanguages, d.subtitleLanguages)
        sponsorBlockRemove = v(.sponsorBlockRemove, d.sponsorBlockRemove)
        sponsorBlockCategories = v(.sponsorBlockCategories, d.sponsorBlockCategories)
        playlist = v(.playlist, d.playlist)
        useDownloadArchive = v(.useDownloadArchive, d.useDownloadArchive)
        rateLimit = v(.rateLimit, d.rateLimit)
        extraArguments = v(.extraArguments, d.extraArguments)
        runMethod = v(.runMethod, d.runMethod)
        shortcutName = v(.shortcutName, d.shortcutName)
        ytDlpCommand = v(.ytDlpCommand, d.ytDlpCommand)
        returnToAppWhenDone = v(.returnToAppWhenDone, d.returnToAppWhenDone)
    }

    /// Short human summary of the extras that are switched on.
    var extrasSummary: String {
        var parts: [String] = []
        if writeThumbnail || embedThumbnail { parts.append("Thumbnail") }
        if embedMetadata { parts.append(channelAsArtist ? "Metadata (channel → artist)" : "Metadata") }
        if mode == .video && downloadSubtitles { parts.append("Subtitles") }
        if sponsorBlockRemove && !sponsorBlockCategories.isEmpty { parts.append("SponsorBlock") }
        if playlist == .full { parts.append("Whole playlists") }
        return parts.isEmpty ? "No extras" : parts.joined(separator: " · ")
    }
}

@Observable
final class PreferencesStore {
    private static let key = "downloadPreferences.v1"

    var prefs: DownloadPreferences {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(DownloadPreferences.self, from: data) {
            prefs = saved
        } else {
            prefs = DownloadPreferences()
        }
    }

    func reset() {
        let keep = (prefs.runMethod, prefs.shortcutName, prefs.ytDlpCommand)
        prefs = DownloadPreferences()
        prefs.runMethod = keep.0
        prefs.shortcutName = keep.1
        prefs.ytDlpCommand = keep.2
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
