# yt-dlp front end for iOS

> Personal-use project. Downloading from YouTube may go against YouTube's Terms of Service, so only download what you have the right to keep. Not affiliated with YouTube, yt-dlp, a-Shell or VLC.

**Sister project:** [yt-dlp-direct-ios](https://github.com/Projectattic/yt-dlp-direct-ios) does the same job with yt-dlp built into the app, so it needs no a-Shell or Shortcuts and shows live progress.

A SwiftUI app for driving the **yt-dlp** you already have installed in **a-Shell**. You set preferences, paste a link, and tap Download. The app builds the yt-dlp command and hands it to a-Shell. Finished downloads show up in a Library with thumbnails, titles, channels and lengths, and you can play them there.

## Build & install

1. Open `YtDlApp.xcodeproj` in Xcode 16 or later.
2. Select the **YtDlApp** target, go to **Signing & Capabilities**, and choose your Team. A free personal Apple ID works.
3. If Xcode complains that the bundle ID `dk.benjy.ytdlapp` is taken, change it to anything unique.
4. Connect your iPhone, select it as the run destination, and press **Run** (⌘R).
5. On the iPhone, if asked, trust the developer under **Settings › General › VPN & Device Management**.

The app requires iOS 17. With a free Apple ID, apps installed from Xcode expire after 7 days, so re-run from Xcode to refresh it.

## One-time set-up on the iPhone

The app contains the same guide under **Settings › Set-up guide**, with copy buttons for each command.

1. **In a-Shell**, run:
   ```
   python3 -m pip install -U yt-dlp mutagen
   python3 -m yt_dlp --version
   mkdir -p ~/Documents/yt-dl
   ```
   mutagen lets yt-dlp embed cover art in M4A files. ffmpeg is built into a-Shell.
   The app runs yt-dlp as `python3 -m yt_dlp` (changeable in Settings), so a stray `yt-dlp` launcher on the PATH — such as one from the SW-DLT shortcut's environment — can't get in the way.
2. **Create a Shortcut** named `yt-dlp`:
   - In the shortcut's details, turn on *Show in Share Sheet* and accept *Text*. This creates the **Shortcut Input** variable.
   - Add the a-Shell action **Execute Command** and set its command to **Shortcut Input**.
   - If the action can either run in the background or open a-Shell, choose to open a-Shell. yt-dlp and ffmpeg need the full app.
3. **Link the Library:** in the app's Library tab, tap *Choose Folder* and pick **On My iPhone › a-Shell › yt-dl**.

If you'd rather not use a Shortcut, set **Settings › Run downloads via** to *Copy & paste*. The command is then copied for you to paste into a-Shell.

## What the default command does

```
python3 -m yt_dlp -P ~/Documents/yt-dl -o "%(title)s.%(ext)s"
       -S vcodec:h264,res:1080,acodec:m4a --merge-output-format mp4
       --write-thumbnail -o "thumbnail:thumbnails/%(title)s.%(ext)s"
       --convert-thumbnails jpg --embed-thumbnail
       --write-info-json --no-write-playlist-metafiles -o "infojson:metadata/%(title)s.%(ext)s"
       --embed-metadata
       --parse-metadata "%(title)s:%(meta_title)s"
       --parse-metadata "%(channel,uploader)s:%(meta_artist)s"
       --parse-metadata "%(channel,uploader)s:%(meta_album_artist)s"
       --embed-chapters --no-playlist -- <link>
```

- **File name** = the video title.
- **Title tag** = the video title. **Artist** and **album artist** = the YouTube channel, falling back to the uploader.
- **Thumbnail:** embedded as cover art, and also saved as a JPG in `thumbnails/` for the Library.
- **Video details** (`metadata/*.info.json`) let the Library show the real title, channel, length, upload date and description.
- **Format:** H.264/AAC MP4, which plays in this app, Photos and Files. Turn off *Prefer iPhone-friendly codecs* to get VP9/AV1 at higher resolutions.

Everything else, including audio format and quality, subtitles, SponsorBlock, playlists, a download archive, a speed limit and free-form extra arguments, is in Settings. The Settings screen shows a live preview of the full command.

## URL scheme

- `ytdlapp://download?url=<encoded link>` opens the app with the link filled in. Use this from a share-sheet shortcut: **URL Encode** the input, then **Open URLs**.
- `ytdlapp://done`, `ytdlapp://error`, `ytdlapp://cancelled` are the Shortcuts callbacks.

## Project layout

```
YtDlApp/
  YtDlpFrontendApp.swift     app entry
  AppState.swift             tab selection, link text, banners
  Models/
    DownloadPreferences.swift  all yt-dlp options (persisted)
    CommandBuilder.swift       preferences → yt-dlp command line
    MediaItem.swift            library item + info.json parsing
  Services/
    AShellRunner.swift         Shortcuts x-callback / clipboard hand-off
    LibraryStore.swift         security-scoped folder access + scanning
    ThumbnailLoader.swift      downsampled, cached thumbnails
  Views/                       Download, Library, detail/player, Settings, guide
```

The project uses Xcode's folder-synced groups, so any new file you add under `YtDlApp/` is picked up automatically.
