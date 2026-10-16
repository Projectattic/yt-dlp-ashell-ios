import SwiftUI

struct SetupGuideView: View {
    @Environment(PreferencesStore.self) private var store

    private var folder: String {
        let f = store.prefs.outputFolder.trimmingCharacters(in: .whitespaces)
        return f.isEmpty ? "~/Documents/yt-dl" : f
    }

    var body: some View {
        List {
            Section {
                Text("Run these once in a-Shell. The first installs or updates yt-dlp plus mutagen (needed to embed cover art in M4A files), the second checks it works, the third creates the download folder.")
                CommandRow(command: DownloadPreferences.updateCommand)
                CommandRow(command: "\(store.prefs.ytDlpCommand) --version")
                CommandRow(command: "mkdir -p \(folder)")
            } header: {
                Text("1 · Prepare a-Shell")
            } footer: {
                Text("ffmpeg, used for merging, converting and embedding, is built into a-Shell.")
            }

            Section {
                Step(n: 1, text: "Open the Shortcuts app and create a new shortcut.")
                Step(n: 2, text: "Rename it to **\(store.prefs.shortcutName.isEmpty ? "yt-dlp" : store.prefs.shortcutName)**. The name must match Settings › Shortcut name exactly.")
                Step(n: 3, text: "Open the shortcut's details (ⓘ) and turn on **Show in Share Sheet**, with Text as the accepted input. This creates the **Shortcut Input** variable.")
                Step(n: 4, text: "Add the a-Shell action **Execute Command** and set its command to the **Shortcut Input** variable.")
                Step(n: 5, text: "If the action can run either in the background or by opening a-Shell, choose to open a-Shell. yt-dlp and ffmpeg need the full app.")
                Step(n: 6, text: "Back here, tap **Download in a-Shell**. The first time, iOS asks for permission to let the shortcut run. Allow it.")
            } header: {
                Text("2 · Create the Shortcut")
            } footer: {
                Text("If you'd rather not use a Shortcut, switch Settings › Run downloads via to Copy & paste.")
            }

            Section {
                Text("To have downloads land in another app's folder, for example so VLC can play them, give a-Shell access to that folder once. Run these in a-Shell:")
                CommandRow(command: "pickFolder")
                Text("Choose **On My iPhone › VLC** (or a folder inside it) and tap Open. a-Shell is now in that folder. Then save it as a bookmark:")
                CommandRow(command: "bookmark VLC")
                Text("Finally enter **VLC** in Settings › Folders › a-Shell bookmark. Each download then starts with `jump VLC`, which moves a-Shell into that folder before yt-dlp runs.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Optional · Save into VLC's folder")
            }

            Section {
                Step(n: 1, text: "Go to the **Library** tab and tap **Choose Folder**.")
                Step(n: 2, text: store.prefs.trimmedBookmark.isEmpty
                     ? "Browse to **On My iPhone › a-Shell** and select the **\((folder as NSString).lastPathComponent)** folder."
                     : "Browse to the folder you bookmarked as **\(store.prefs.trimmedBookmark)** (e.g. **On My iPhone › VLC**) and select it.")
            } header: {
                Text("3 · Link the Library")
            } footer: {
                Text("The Library refreshes every time you come back to the app. You can also pull down to refresh.")
            }

            Section {
                Text("To send links straight from the YouTube app's share sheet, create a second shortcut that receives URLs and has these actions:")
                Step(n: 1, text: "**URL Encode** the Shortcut Input.")
                Step(n: 2, text: "**Open URLs**: ytdlapp://download?url= followed by the URL Encoded Text.")
                Text("This opens the app with the link filled in, ready to download.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Optional · Share from YouTube")
            }

            Section {
                Text("**Nothing appears in the Library:** check that “Save to” and the linked folder are the same folder, and that the download finished in a-Shell.")
                Text("**Downloads suddenly fail:** YouTube changes often. Tap Settings › Update yt-dlp.")
                Text("**No module named 'yt_dlp':** yt-dlp isn't installed where a-Shell's Python can see it, which can happen if it was installed by another Shortcut's private environment. Run the install command in step 1.")
                Text("**No cover art in M4A files:** run `python3 -m pip install mutagen` in a-Shell.")
            } header: {
                Text("Troubleshooting")
            }
            .font(.callout)
        }
        .navigationTitle("Set-up guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Step: View {
    let n: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(LocalizedStringKey(text))
        }
    }
}

private struct CommandRow: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button {
                UIPasteboard.general.string = command
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy command")
        }
    }
}
