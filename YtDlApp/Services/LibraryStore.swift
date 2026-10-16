import Foundation
import Observation

/// Reads the folder that a-Shell downloads into, via a security-scoped bookmark.
@MainActor
@Observable
final class LibraryStore {
    private(set) var items: [MediaItem] = []
    private(set) var folderURL: URL?
    private(set) var isLoading = false
    var lastError: String?

    private var accessedURL: URL?
    private static let bookmarkKey = "libraryFolderBookmark"

    init() {
        restoreFolder()
    }

    // MARK: Folder access

    func setFolder(_ url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
            beginAccess(url, alreadyStarted: started)
            refresh()
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            lastError = "Couldn't remember that folder: \(error.localizedDescription)"
        }
    }

    func forgetFolder() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        folderURL = nil
        items = []
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
    }

    private func restoreFolder() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            let started = url.startAccessingSecurityScopedResource()
            if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
            }
            beginAccess(url, alreadyStarted: started)
            refresh()
        } catch {
            lastError = "The linked folder can't be found any more. Please link it again."
        }
    }

    private func beginAccess(_ url: URL, alreadyStarted: Bool) {
        if let old = accessedURL { old.stopAccessingSecurityScopedResource() }
        if !alreadyStarted { _ = url.startAccessingSecurityScopedResource() }
        accessedURL = url
        folderURL = url
    }

    // MARK: Scanning

    func refresh() {
        Task { await reload() }
    }

    func reload() async {
        guard let folder = folderURL else {
            items = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let scanned = try await Task.detached(priority: .userInitiated) {
                try LibraryScanner.scan(folder)
            }.value
            items = scanned
            lastError = nil
        } catch {
            lastError = "Couldn't read the folder: \(error.localizedDescription)"
        }
    }

    // MARK: Deleting

    func delete(_ item: MediaItem) {
        let fm = FileManager.default
        do {
            try fm.removeItem(at: item.url)
            // Remove the thumbnail and details only if no other file (e.g. an audio
            // version of the same video) still uses them.
            let shared = items.contains { $0.url != item.url && $0.stem == item.stem }
            if !shared {
                for sidecar in [item.thumbnailURL, item.metadataURL].compactMap({ $0 }) {
                    try? fm.removeItem(at: sidecar)
                }
            }
            items.removeAll { $0.url == item.url }
        } catch {
            lastError = "Couldn't delete “\(item.title)”: \(error.localizedDescription)"
        }
    }
}

enum LibraryScanner {
    static let videoExtensions: Set<String> = ["mp4", "m4v", "mov", "mkv", "webm"]
    static let audioExtensions: Set<String> = ["m4a", "mp3", "opus", "ogg", "flac", "wav", "aac"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]

    static func scan(_ folder: URL) throws -> [MediaItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .contentModificationDateKey]

        let rootFiles = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        func list(_ name: String) -> [URL] {
            (try? fm.contentsOfDirectory(at: folder.appendingPathComponent(name, isDirectory: true),
                                         includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        }
        let sidecarCandidates = rootFiles + list("thumbnails") + list("metadata")

        // Index thumbnails and info.json files by the file name they belong to.
        var thumbnails: [String: URL] = [:]
        var metadata: [String: URL] = [:]
        for file in sidecarCandidates {
            let name = file.lastPathComponent
            if name.lowercased().hasSuffix(".info.json") {
                metadata[String(name.dropLast(".info.json".count))] = file
            } else if imageExtensions.contains(file.pathExtension.lowercased()) {
                let stem = file.deletingPathExtension().lastPathComponent
                if thumbnails[stem] == nil || file.pathExtension.lowercased() == "jpg" {
                    thumbnails[stem] = file
                }
            }
        }

        var items: [MediaItem] = []
        for file in rootFiles {
            let ext = file.pathExtension.lowercased()
            let kind: MediaKind
            if videoExtensions.contains(ext) { kind = .video }
            else if audioExtensions.contains(ext) { kind = .audio }
            else { continue }

            // Skip files yt-dlp is still working on (partial downloads, pre-merge streams).
            let name = file.lastPathComponent
            if name.contains(".part") || name.contains(".temp.")
                || name.range(of: #"\.f[0-9]+(-[0-9]+)?\.[A-Za-z0-9]+$"#, options: .regularExpression) != nil {
                continue
            }

            let stem = file.deletingPathExtension().lastPathComponent
            let values = try? file.resourceValues(forKeys: Set(keys))
            let info = metadata[stem].flatMap(InfoJSON.load)

            items.append(MediaItem(
                url: file,
                kind: kind,
                title: info?.title ?? stem,
                channel: info?.channel ?? info?.uploader,
                duration: info?.duration,
                uploadDate: info?.uploadDateValue,
                webpageURL: info?.webpageURL.flatMap(URL.init(string:)),
                viewCount: info?.viewCount,
                summary: info?.description,
                thumbnailURL: thumbnails[stem],
                metadataURL: metadata[stem],
                fileSize: values?.fileSize.map { Int64($0) },
                dateAdded: values?.creationDate ?? values?.contentModificationDate ?? .distantPast
            ))
        }
        return items.sorted { $0.dateAdded > $1.dateAdded }
    }
}
