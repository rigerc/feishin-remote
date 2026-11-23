---
title: Security
description: How Feishin Remote stores and sends credentials.
---

Feishin serves HTTP and WebSocket traffic without TLS by default. Basic Auth credentials can therefore be observed by other devices on an untrusted network.

- Use a unique Remote password.
- Use the app only on a trusted LAN, or put Feishin behind an HTTPS/WSS reverse proxy you control.

## What the app stores

- Saved server addresses, usernames, and theme choices are kept in the app's private storage.
- Passwords are stored separately, encrypted with Android Keystore. They are never written to SharedPreferences or application logs.
- Deleting a saved server removes its password. Uninstalling the app removes everything it stored.
- Android cloud backup is disabled, so encrypted values are never restored without their Keystore keys.

The app connects only to the Feishin servers you enter. See the [privacy policy](../../privacy/) for details.
