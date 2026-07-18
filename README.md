<p align="center">
  <img src="assets/logo.png" width="144" alt="Feishin Remote logo">
</p>

# Feishin Remote

Android remote control for a running [Feishin](https://github.com/jeffvli/feishin) desktop player. It connects directly to Feishin's Remote WebSocket API; audio continues to play on the computer.

## Features

- Play, pause, previous, next, seek, volume, shuffle, and repeat controls
- Live artwork, favorite state, rating, and playback position
- Track year, genre, format, bitrate, sample rate, bit depth, track/disc number, and play count
- Multiple saved Feishin server profiles
- Password encryption through Android Keystore
- Automatic reconnect with bounded exponential backoff
- Android notification, lock-screen, headset, and Bluetooth media controls
- Persistent light and dark themes

## Requirements

- Android device and Feishin computer on the same network
- Feishin desktop application; Remote is not exposed by the browser build
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

- Flutter 3.44 or newer
- Android SDK
- Java 17

Install packages and run:

```sh
flutter pub get
flutter run
```

Run checks:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build a debug APK:

```sh
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## CI and releases

`.github/workflows/android-ci.yml` validates every relevant push and pull request. It checks formatting, runs analysis and tests with coverage, builds a debug APK, and uploads the APK and coverage report as workflow artifacts.

`.github/workflows/android-release.yml` creates signed GitHub Releases from `v*.*.*` tags or a manual workflow dispatch. Release builds are obfuscated, signature-verified, and published with a SHA-256 checksum. Obfuscation symbols are retained as a private workflow artifact for crash symbolication.

### Create the signing key

Generate the key once and keep an offline backup:

```sh
keytool -genkeypair -v \
  -keystore release.jks \
  -alias feishin-remote \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Add these encrypted repository secrets under **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded contents of `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias, such as `feishin-remote` |
| `ANDROID_KEY_PASSWORD` | Private-key password |

Create the Base64 value on Linux with:

```sh
base64 -w 0 release.jks
```

Never commit the keystore or passwords. The workflow decodes the key only for the build and removes it afterward.

### Publish a release

Create and push a SemVer tag:

```sh
git tag -a v1.0.0 -m "Feishin Remote 1.0.0"
git push origin v1.0.0
```

The tag determines the Android version name. The GitHub run number becomes the monotonically increasing version code. A release can also be started manually from **Actions → Android Release → Run workflow**.

### Build a signed release locally

```sh
export ANDROID_KEYSTORE_PATH="$PWD/android/app/release.jks"
export ANDROID_KEYSTORE_PASSWORD='your-keystore-password'
export ANDROID_KEY_ALIAS='feishin-remote'
export ANDROID_KEY_PASSWORD='your-key-password'

flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info=build/symbols/local

unset ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_PASSWORD
```

A release build intentionally fails when any signing variable is absent rather than producing a debug-signed release.

## Project layout

```text
lib/app_storage.dart          Saved profiles, theme preference, secure passwords
lib/feishin_remote.dart       WebSocket protocol, state parsing, reconnect logic
lib/remote_audio_handler.dart Android media-session bridge
lib/remote_app.dart           Material UI
assets/logo.svg               Editable logo source
assets/logo.png               In-app and README logo
```
