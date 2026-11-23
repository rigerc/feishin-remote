<p align="center">
  <img src="assets/logo.png" width="144" alt="Feishin Remote logo">
</p>

# Feishin Remote

Android remote control for a running [Feishin](https://github.com/jeffvli/feishin) desktop player. It connects directly to Feishin's Remote WebSocket API; audio continues to play on the computer.

## Features

- Play, pause, previous, next, seek, volume, shuffle, and repeat controls
- Now Playing with fullscreen artwork, favorites, rating, and mute with volume restore
- Search and browse tracks, albums, playlists, and internet radio stations
- Play now, next, or last with shuffle options, start Track Radio, and add songs to playlists
- View, search, jump within, reorder, remove from, and clear the live desktop queue
- Optional matching of the desktop accent in either Android theme
- Track year, genre, format, bitrate, sample rate, bit depth, track/disc number, and play count
- Multiple saved Feishin server profiles
- Password encryption through Android Keystore
- Automatic reconnect with bounded exponential backoff
- Android notification, lock-screen, headset, and Bluetooth media controls
- Persistent light and dark themes

## Requirements

- Android device and Feishin computer on the same network
- Feishin desktop application with Remote enabled
- Feishin 1.16.0 or newer for browsing, playlist actions, radio, and queue management. Earlier versions support basic playback controls.
- Feishin Remote enabled and reachable through its configured port (`4333` by default)

## Configure Feishin

1. Open **Settings → Window** in Feishin.
2. Scroll to the **Remote** section.
3. Enable **Remote control server**.
4. Note the port and optionally configure a username and unique password.
5. Find the computer's LAN address, such as `192.168.1.20`.

The resulting address is normally:

```text
http://192.168.1.20:4333
```

## Connect the app

1. Enter the Remote URL and optional credentials.
2. Tap **Save server** to retain the profile. The address and username use app preferences; the password is stored separately using Android Keystore encryption.
3. Tap **Connect**.
4. Select another saved profile after disconnecting. The last selected profile reconnects automatically when the app starts.

Unexpected disconnects retry after 2, 4, 8, 16, and then 30 seconds, stopping after eight attempts. A manual disconnect cancels retries.

Android media controls become available when Feishin reports a current track. They control Feishin remotely and do not play audio on the phone.

## Security

Feishin serves HTTP and WebSocket traffic without TLS by default. Basic Auth credentials can therefore be observed by other devices on an untrusted network.

- Use a unique Remote password.
- Use the app only on a trusted LAN, or place Feishin behind an HTTPS/WSS reverse proxy.
- Passwords are never written to SharedPreferences or application logs.
- Android cloud backup is disabled to avoid restoring encrypted values without their Keystore keys.

## Development

Prerequisites:

- Flutter 3.47.5 (see `.fvmrc`)
- Android SDK
- Java 17

Install packages and run:

```sh
flutter pub get
flutter run
```

Run the full check (format, analysis with fatal infos, tests with coverage):

```sh
tool/verify.sh
```

Build a debug APK:

```sh
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The Flutter version is pinned in `.fvmrc`. The app name, description and Android application ID live in `project.json`. Keep `applicationId` unchanged: installed copies upgrade only when it and the signing key match.

## Screenshots, video, and website

```sh
tool/media.sh               # screenshots and video
tool/media.sh screenshots   # stills only
tool/media.sh video         # video and poster only
tool/site.sh                # install website dependencies, check, and build
```

`tool/capture_test.dart` renders the real app against a fake Feishin desktop on a local socket, using a fictional library and generated artwork. It needs FFmpeg with WebP and H.264 encoders. PNGs and the video are written to `build/media`, and the website assets to `website/public/media`.

`website/` is an [Astro Rocket](https://github.com/hansmartensdev/Astro-Rocket) site with [Starlight](https://starlight.astro.build/) docs, built from [project-website-bootstrap](https://github.com/rigerc/project-website-bootstrap). It needs Node.js (see `website/.nvmrc`) and pnpm. `tool/site.sh` runs its lint, type checks, unit tests, build, and output checks; the build is in `website/dist`. For local development run `pnpm dev` in `website/`. See [website/README.md](website/README.md) and the site's **Website and media** docs page.

The **Website and media** workflow captures the app media, builds the site, captures website screenshots with Playwright, and uploads `website-preview`, `app-media`, and `site-media` artifacts. To deploy, set **Settings → Pages → Source → GitHub Actions** and add the Actions variable `PAGES_ENABLED=true`. The workflow passes the Pages origin and sub-path to the build as `SITE_URL` and `BASE_PATH`.

## CI and releases

`.github/workflows/ci.yml` runs `tool/verify.sh`, builds a debug APK, and uploads it and the coverage report as workflow artifacts.

### Release

1. Increase `version: X.Y.Z+N` in `pubspec.yaml` and add a matching `## X.Y.Z` entry in `CHANGELOG.md`. The build number `N` becomes the Android version code and must increase with every release. `v0.1.0` and `v0.1.1` used build numbers 1 and 2.
2. Run `tool/verify.sh` and `tool/android_release.sh --dry-run`. **Actions → Android release → Run workflow** offers the same preflight.
3. Push a matching `vX.Y.Z` tag from a commit on the default branch. With signing configured, CI verifies the signed APK and creates a **draft** GitHub release containing the APK, release notes, metadata, and SHA-256 checksums. The obfuscation symbols are kept for 90 days as a separate workflow artifact for crash symbolication.
4. Check the checksums, install the APK over the previous version, then publish the draft.

Validate a downloaded release with `sha256sum --check SHA256SUMS`. If creating the draft failed partway, remove the incomplete draft before retrying the same tag. Never reuse or move a published tag. Ship fixes under a new version with a higher build number.

### Android signing

Generate the key once and keep an offline backup. Use the same key as earlier releases so installed copies can upgrade.

```sh
keytool -genkeypair -v \
  -keystore release.jks \
  -alias feishin-remote \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

For GitHub Actions, create an environment named `android-signing` (set its deployment tag rule to `v*` and require reviewers where supported) and add these environment secrets:

| Local environment variable | GitHub Actions environment secret |
| --- | --- |
| `ANDROID_KEYSTORE_PATH` (absolute path) | `ANDROID_KEYSTORE_BASE64` (`base64 -w 0 release.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | `ANDROID_KEYSTORE_PASSWORD` |
| `ANDROID_KEY_ALIAS` | `ANDROID_KEY_ALIAS` |
| `ANDROID_KEY_PASSWORD` | `ANDROID_KEY_PASSWORD` |

Never commit the keystore or passwords. To build a signed release locally, set the four variables above and run:

```sh
ANDROID_HOME=/path/to/android-sdk tool/android_release.sh
```

The output is in `dist/release`. The build is obfuscated and checked for its signature, application ID, and notification icon. A plain `flutter build apk --release` intentionally fails when any signing variable is absent rather than producing a debug-signed release.

## Project layout

```text
lib/app_storage.dart          Saved profiles, theme preference, secure passwords
lib/feishin_remote.dart       WebSocket session, requests, playback, and reconnect logic
lib/remote_protocol.dart      Library, queue, radio, and accent wire models
lib/remote_audio_handler.dart Android media-session bridge
lib/remote_app.dart           Material navigation, connection setup, and Now Playing
lib/remote_browser.dart       Catalogs, queue, and playback actions
assets/logo.svg               Editable logo source
assets/logo.png               In-app and README logo
project.json                  App name, description, application ID
tool/                         Verification, release, media, and site scripts
website/                      Product site and docs (Astro Rocket + Starlight)
CHANGELOG.md                  Release notes
```
