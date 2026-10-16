import UIKit

/// Hands a command over to a-Shell.
///
/// Apps can't start another app's process directly, so the command goes through
/// a Shortcut ("Execute Command" from a-Shell) via the Shortcuts x-callback URL,
/// or is copied to the clipboard for pasting into a-Shell.
enum AShellRunner {
    enum Outcome {
        case launchedShortcut
        case copiedAndOpenedAShell
        case copiedOnly
        case failed(String)
    }

    @MainActor
    static func run(_ command: String, prefs: DownloadPreferences) async -> Outcome {
        switch prefs.runMethod {
        case .shortcut:
            let name = prefs.shortcutName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, let url = shortcutURL(name: name, input: command) else {
                return .failed("Set the Shortcut name in Settings first.")
            }
            let opened = await UIApplication.shared.open(url)
            return opened ? .launchedShortcut : .failed("Couldn't open the Shortcuts app.")

        case .clipboard:
            UIPasteboard.general.string = command
            if let aShell = URL(string: "ashell://"), await UIApplication.shared.open(aShell) {
                return .copiedAndOpenedAShell
            }
            return .copiedOnly
        }
    }

    static func shortcutURL(name: String, input: String) -> URL? {
        let query = [
            "name=" + encode(name),
            "input=text",
            "text=" + encode(input),
            // No x-success: returning here as soon as the Shortcut hands off would send
            // a-Shell to the background and stall the download. a-Shell itself switches
            // back via `open ytdlapp://finished` once yt-dlp is done.
            "x-cancel=" + encode("ytdlapp://cancelled"),
            "x-error=" + encode("ytdlapp://error"),
        ].joined(separator: "&")
        return URL(string: "shortcuts://x-callback-url/run-shortcut?" + query)
    }

    /// Strict percent-encoding: only unreserved ASCII characters are left as-is.
    static func encode(_ s: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
