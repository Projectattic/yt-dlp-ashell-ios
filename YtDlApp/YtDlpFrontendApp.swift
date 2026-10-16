import SwiftUI
import AVFoundation

@main
struct YtDlpFrontendApp: App {
    @State private var appState = AppState()
    @State private var preferences = PreferencesStore()
    @State private var library = LibraryStore()

    init() {
        // Let audio play with the ring/silent switch on and in the background.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(preferences)
                .environment(library)
        }
    }
}
