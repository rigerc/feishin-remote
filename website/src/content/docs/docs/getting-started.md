---
title: Getting started
description: Enable Remote in Feishin, install the app, and connect.
---

## 1. Enable Remote in Feishin

1. Open **Settings → Window** in Feishin.
2. Scroll to the **Remote** section.
3. Enable **Remote control server**.
4. Note the port, and optionally set a username and a unique password.
5. Find the computer's LAN address, such as `192.168.1.20`.

The address you enter in the app is normally:

```text
http://192.168.1.20:4333
```

## 2. Install the app

Download the APK from the [latest release](https://github.com/rigerc/feishin-remote/releases/latest) and open it on your phone. Android asks once for permission to install apps from your browser or file manager.

Each release includes a `SHA256SUMS` file. To check a download on a computer:

```sh
sha256sum --check SHA256SUMS
```

Installing a newer APK upgrades the app and keeps your saved servers.

## 3. Connect

1. Enter the Remote URL and any username and password you set.
2. Tap **Save server** to keep the profile. The address and username are stored in the app's preferences; the password is stored separately with Android Keystore encryption.
3. Tap **Connect**.

To switch computers, disconnect and pick another saved profile. The last selected profile reconnects automatically when the app starts.

If the connection drops unexpectedly, the app retries after 2, 4, 8, 16, and then 30 seconds, and stops after eight attempts. Disconnecting manually cancels the retries.

Next: [Using the app](../using-the-app/).
