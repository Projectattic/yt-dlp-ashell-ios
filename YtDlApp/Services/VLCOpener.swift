import UIKit

/// Opens a local file in VLC via its x-callback URL scheme.
/// Works best for files inside VLC's own folder, which VLC can read directly.
enum VLCOpener {
    static let settingKey = "openInVLC"

    @MainActor
    static func open(_ fileURL: URL) async -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        guard let encoded = fileURL.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "vlc-x-callback://x-callback-url/stream?url=\(encoded)") else { return false }
        return await UIApplication.shared.open(url)
    }
}
