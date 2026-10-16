import Foundation

/// Turns `DownloadPreferences` into a yt-dlp command line for a-Shell.
enum CommandBuilder {

    /// The single line sent to a-Shell. A folder bookmark is passed as `~NAME`, which
    /// a-Shell expands to the bookmarked folder. (Shortcut commands each start in
    /// a-Shell's `~group` folder, so a separate `jump` line doesn't carry over.)
    static func command(urls: [String], prefs: DownloadPreferences) -> String {
        var program = tokenize(prefs.ytDlpCommand)
        if program.isEmpty { program = tokenize(DownloadPreferences.defaultYtDlpCommand) }
        let ytdlp = (program + arguments(urls: urls, prefs: prefs)).map(quote).joined(separator: " ")
        // a-Shell runs each line in turn, so this fires once yt-dlp has finished (or failed).
        return prefs.returnToAppWhenDone ? ytdlp + "\nopen ytdlapp://finished" : ytdlp
    }

    static func arguments(urls: [String], prefs p: DownloadPreferences) -> [String] {
        var a: [String] = []

        // Where and how files are named
        let pathFolder = p.outputFolder.trimmingCharacters(in: .whitespaces)
        let folder = !p.trimmedBookmark.isEmpty ? "~" + p.trimmedBookmark
            : (pathFolder.isEmpty ? "~/Documents/yt-dl" : pathFolder)
        a += ["-P", folder]

        var template = p.filenameStyle == .custom
            ? p.customTemplate.trimmingCharacters(in: .whitespaces)
            : p.filenameStyle.template
        if template.isEmpty { template = FilenameStyle.title.template }
        a += ["-o", template]
        if p.restrictFilenames { a.append("--restrict-filenames") }

        // Format selection
        switch p.mode {
        case .video:
            let compatible = p.preferCompatibleCodecs && p.videoContainer == .mp4
            var sort: [String] = []
            if compatible { sort.append("vcodec:h264") }
            if let h = p.videoQuality.height { sort.append("res:\(h)") }
            if compatible { sort.append("acodec:m4a") }
            if !sort.isEmpty { a += ["-S", sort.joined(separator: ",")] }
            a += ["--merge-output-format", p.videoContainer.rawValue]

            if p.downloadSubtitles {
                a.append("--write-subs")
                if p.autoSubtitles { a.append("--write-auto-subs") }
                let langs = p.subtitleLanguages.trimmingCharacters(in: .whitespaces)
                a += ["--sub-langs", langs.isEmpty ? "en.*" : langs, "--embed-subs"]
            }

        case .audio:
            a += ["-f", p.audioFormat == .m4a ? "ba[ext=m4a]/ba/b" : "ba/b"]
            a += ["-x", "--audio-format", p.audioFormat.rawValue]
            if p.audioFormat.isLossy { a += ["--audio-quality", p.audioQuality.rawValue] }
        }

        // Thumbnail: saved next to the file (for the Library) and/or embedded as cover art
        if p.writeThumbnail {
            a.append("--write-thumbnail")
            if p.sidecarsInSubfolders { a += ["-o", "thumbnail:thumbnails/" + template] }
        }
        if p.writeThumbnail || p.embedThumbnail {
            a += ["--convert-thumbnails", "jpg"]
        }
        if p.embedThumbnail { a.append("--embed-thumbnail") }

        // Video details for the Library (title, channel, duration, …)
        if p.writeInfoJSON {
            a += ["--write-info-json", "--no-write-playlist-metafiles"]
            if p.sidecarsInSubfolders { a += ["-o", "infojson:metadata/" + template] }
        }

        // Tags inside the file
        if p.embedMetadata {
            a.append("--embed-metadata")
            a += ["--parse-metadata", "%(title)s:%(meta_title)s"]
            if p.channelAsArtist {
                a += ["--parse-metadata", "%(channel,uploader)s:%(meta_artist)s"]
                a += ["--parse-metadata", "%(channel,uploader)s:%(meta_album_artist)s"]
            }
            if p.channelAsAlbum {
                a += ["--parse-metadata", "%(channel,uploader)s:%(meta_album)s"]
            }
        }
        a.append(p.embedChapters ? "--embed-chapters" : "--no-embed-chapters")

        if p.sponsorBlockRemove && !p.sponsorBlockCategories.isEmpty {
            a += ["--sponsorblock-remove", p.sponsorBlockCategories.joined(separator: ",")]
        }

        a.append(p.playlist == .single ? "--no-playlist" : "--yes-playlist")

        if p.useDownloadArchive {
            a += ["--download-archive", folder + "/archive.txt"]
        }

        let rate = p.rateLimit.trimmingCharacters(in: .whitespaces)
        if !rate.isEmpty { a += ["-r", rate] }

        a += tokenize(p.extraArguments)

        a.append("--")
        a += urls
        return a
    }

    // MARK: - Helpers

    /// Quotes an argument for a-Shell only when needed.
    static func quote(_ s: String) -> String {
        let safe = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:=,+@~%")
        // Left unquoted so a-Shell can expand `~` and `~BOOKMARK` paths.
        if !s.isEmpty, s.allSatisfy({ safe.contains($0) }) {
            // %( … )s templates contain parentheses, so they always end up quoted.
            return s
        }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    /// Splits user-typed extra arguments, honouring straight and curly quotes.
    static func tokenize(_ s: String) -> [String] {
        let doubleQuotes: Set<Character> = ["\"", "“", "”"]
        let singleQuotes: Set<Character> = ["'", "‘", "’"]
        var out: [String] = []
        var current = ""
        var inToken = false
        var openQuotes: Set<Character>? = nil

        for ch in s {
            if let q = openQuotes {
                if q.contains(ch) { openQuotes = nil } else { current.append(ch) }
            } else if doubleQuotes.contains(ch) {
                openQuotes = doubleQuotes; inToken = true
            } else if singleQuotes.contains(ch) {
                openQuotes = singleQuotes; inToken = true
            } else if ch.isWhitespace {
                if inToken { out.append(current); current = ""; inToken = false }
            } else {
                current.append(ch); inToken = true
            }
        }
        if inToken { out.append(current) }
        return out
    }

    /// Pulls individual links out of whatever was pasted.
    static func links(from text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
