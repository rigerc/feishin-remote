---
title: Website and media
description: Capture app screenshots and video, and build and deploy this site.
---

The site is an [Astro Rocket](https://github.com/hansmartensdev/Astro-Rocket) single-project site with [Starlight](https://starlight.astro.build/) docs, in `website/`. It uses Node.js (see `website/.nvmrc`) and pnpm.

## App screenshots and video

```sh
tool/media.sh               # screenshots and video
tool/media.sh screenshots   # stills only
tool/media.sh video         # video and poster only
```

`tool/capture_test.dart` renders the real app against a fake Feishin desktop on a local socket, using a fictional library and generated artwork. It needs FFmpeg with WebP and H.264 encoders. PNGs and the video go to `build/media`; the WebP and MP4 files the site uses go to `website/public/media`, which is not committed.

## Build the site

```sh
tool/site.sh
```

This installs the site's dependencies and runs lint, type checks, unit tests, the build, and the route and output checks. It stops early if the app media is missing. For local development:

```sh
cd website
pnpm dev
```

| File | What it controls |
| --- | --- |
| `website/src/config/branding.ts` | Site name, repository, theme colour, and logo |
| `website/src/config/project.config.ts` | Homepage copy, download link, features, setup steps, FAQ |
| `website/src/config/nav.config.ts` | Header and footer links |
| `website/src/content/docs/docs/` | These docs |
| `website/src/pages/privacy.astro`, `support.astro` | Privacy policy and support page |

## Website screenshots

With the built site served by `pnpm preview`, Playwright captures the site itself:

```sh
cd website
pnpm exec playwright install chromium
pnpm media:capture   # desktop and mobile screenshots
pnpm media:video     # scrolling walkthrough, needs FFmpeg
```

Output goes to `website/media-output/`, which is not committed.

## Deploy

The **Website and media** workflow captures the app media, builds and checks the site, captures website screenshots, and uploads `website-preview`, `app-media`, and `site-media` artifacts.

To publish on GitHub Pages, set **Settings → Pages → Source** to **GitHub Actions** and add the Actions variable `PAGES_ENABLED=true`. The workflow then deploys the default branch. It passes the Pages origin and sub-path to the build as `SITE_URL` and `BASE_PATH`. With a custom domain the sub-path is empty. To reproduce a Pages build locally:

```sh
SITE_URL=https://rigerc.github.io BASE_PATH=/feishin-remote pnpm build
```

Links written by hand in pages must go through `withBase()` from `src/lib/base.ts`; links inside the docs markdown should be relative. The download button links to the latest GitHub release.
