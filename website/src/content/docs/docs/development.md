---
title: Development
description: Build, run, and test the Flutter app.
---

## Prerequisites

- Flutter, pinned in `.fvmrc`
- Android SDK
- Java 17

## Run

```sh
flutter pub get
flutter run
```

## Check

Run the full check: formatting, analysis with fatal infos, and tests with coverage.

```sh
tool/verify.sh
```

Build a debug APK:

```sh
flutter build apk --debug
```

The output is `build/app/outputs/flutter-apk/app-debug.apk`.

## Project layout

```text
lib/app_storage.dart          Saved profiles, theme preference, secure passwords
lib/feishin_remote.dart       WebSocket session, requests, playback, and reconnect logic
lib/remote_protocol.dart      Library, queue, radio, and accent wire models
lib/remote_audio_handler.dart Android media-session bridge
lib/remote_app.dart           Material navigation, connection setup, and Now Playing
lib/remote_browser.dart       Catalogs, queue, and playback actions
assets/logo.svg               Editable logo source, also used by the website
project.json                  App name, description, and application ID
tool/                         Verification, release, media, and site scripts
website/                      This website
```

The app name, description, and Android application ID live in `project.json`. Keep `applicationId` unchanged: installed copies upgrade only when it and the signing key match.

## Continuous integration

`.github/workflows/ci.yml` runs `tool/verify.sh`, builds a debug APK, and uploads it and the coverage report as workflow artifacts.
