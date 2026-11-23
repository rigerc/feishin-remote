---
title: Troubleshooting
description: What to check when the app does not connect or a feature is missing.
---

## The app does not connect

- Check that Feishin is running and **Remote control server** is enabled under **Settings → Window**.
- Use the computer's LAN address, not `localhost`. The phone and the computer must be on the same network.
- Include the scheme and port, for example `http://192.168.1.20:4333`.
- Open the same address in the phone's browser. If it does not load, a firewall on the computer may be blocking the port.
- If you set a username and password in Feishin, enter the same ones in the app.

## Library, playlists, radio, or the queue are missing

These need Feishin 1.16.0 or newer. Earlier versions support basic playback controls only. Update Feishin on your computer and reconnect.

## Media controls do not appear

The notification appears once Feishin reports a current track. Start playback in Feishin, and check that notifications are allowed for Feishin Remote in Android settings.

## The app keeps reconnecting

The app retries a dropped connection up to eight times, waiting up to 30 seconds between attempts. If the network changes often, for example when the phone switches between Wi-Fi and mobile data, connect again once it is back on the home network.

## Still stuck?

[Report a problem](https://github.com/rigerc/feishin-remote/issues/new) with your Android version, your Feishin version, and what you tried.
