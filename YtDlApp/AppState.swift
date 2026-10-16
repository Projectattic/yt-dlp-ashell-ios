import Foundation
import Observation

struct Banner: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

/// A download handed to a-Shell, tracked so the app can report how it went.
struct ActiveDownload: Equatable {
    enum State: Equatable { case running, finished, failed }
    let links: [String]
    let startedAt: Date
    var state: State = .running
    var results: [MediaItem] = []
}

@MainActor
@Observable
final class AppState {
    enum Tab: Hashable { case download, library, settings }

    var selectedTab: Tab = .download
    var linkText = ""
    var banner: Banner?
    var activeDownload: ActiveDownload?

    func startTracking(links: [String]) {
        activeDownload = ActiveDownload(links: links, startedAt: Date())
    }

    /// Re-scans the library and looks for files created since the download started.
    /// `finished` is true when a-Shell signalled that yt-dlp has exited.
    func checkActiveDownload(in library: LibraryStore, finished: Bool) async {
        await library.reload()
        guard var download = activeDownload, download.state == .running else { return }
        let since = download.startedAt.addingTimeInterval(-5)
        let newItems = library.items.filter { $0.dateAdded >= since }
        if !newItems.isEmpty && finished {
            download.state = .finished
            download.results = newItems
        } else if !newItems.isEmpty {
            // A file appeared, but without the finish signal more may still be coming.
            download.results = newItems
        } else if finished {
            download.state = .failed
        }
        activeDownload = download
    }

    func show(_ message: String, isError: Bool = false) {
        let banner = Banner(message: message, isError: isError)
        self.banner = banner
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(isError ? 6 : 4))
            if self.banner?.id == banner.id { self.banner = nil }
        }
    }

    func report(_ outcome: AShellRunner.Outcome) {
        switch outcome {
        case .launchedShortcut:
            break // We're leaving the app; the callback URL reports back.
        case .copiedAndOpenedAShell:
            break
        case .copiedOnly:
            show("Command copied. Open a-Shell and paste it.")
        case .failed(let message):
            show(message, isError: true)
        }
    }
}
