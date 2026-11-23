---
title: Releases
description: Version, sign, and publish an Android release.
---

## Release

1. Increase `version: X.Y.Z+N` in `pubspec.yaml` and add a matching `## X.Y.Z` entry in `CHANGELOG.md`. The build number `N` becomes the Android version code and must increase with every release.
2. Run `tool/verify.sh` and `tool/android_release.sh --dry-run`. **Actions → Android release → Run workflow** offers the same preflight.
3. Push a matching `vX.Y.Z` tag from a commit on the default branch. With signing configured, CI verifies the signed APK and creates a **draft** GitHub release containing the APK, release notes, metadata, and SHA-256 checksums. The obfuscation symbols are kept for 90 days as a separate workflow artifact.
4. Check the checksums, install the APK over the previous version, then publish the draft.

If creating the draft failed partway, remove the incomplete draft before retrying the same tag. Never reuse or move a published tag; ship fixes under a new version with a higher build number.

## Android signing

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

Never commit the keystore or passwords. To build a signed release locally, set the four variables and run:

```sh
ANDROID_HOME=/path/to/android-sdk tool/android_release.sh
```

The output is in `dist/release`. A plain `flutter build apk --release` intentionally fails when any signing variable is missing, rather than producing a debug-signed release.
