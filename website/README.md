# Feishin Remote website

The product site and documentation for [Feishin Remote](https://github.com/rigerc/feishin-remote), built from [project-website-bootstrap](https://github.com/rigerc/project-website-bootstrap): an [Astro Rocket](https://github.com/hansmartensdev/Astro-Rocket) single-project site with [Starlight](https://starlight.astro.build/) docs.

## Develop

The homepage shows screenshots and a video captured from the real app. Generate them from the repository root first; they are written to `public/media/` and are not committed:

```bash
tool/media.sh
```

Then, in this directory:

```bash
corepack enable
pnpm install
pnpm dev
```

The homepage is `/`, the docs are at `/docs/`, and `/privacy/` and `/support/` are plain pages. Edit `src/config/project.config.ts` for homepage copy, `src/config/branding.ts` for the name, repository, colour, and logo, and `src/content/docs/docs/` for the docs.

## Test and build

```bash
pnpm lint
pnpm check
pnpm test:run
pnpm build
pnpm check:site
pnpm verify
```

`tool/site.sh` in the repository root runs all of these. `pnpm validate` runs them from here.

## Website screenshots and video

With a production preview on `localhost:4321` (`pnpm preview`; pass the same `BASE_PATH` as the build, and set `PLAYWRIGHT_BASE_URL` to include it):

```bash
pnpm exec playwright install chromium
pnpm media:capture   # desktop and mobile screenshots of / and /docs/
pnpm media:video     # browser walkthrough MP4; requires FFmpeg
pnpm media:all       # both
```

Output goes to `media-output/`, which is not committed. These capture the website itself; app screenshots come from `tool/media.sh`.

## Publishing

The repository's **Website and media** workflow builds the site and, with `PAGES_ENABLED=true` set as an Actions variable, deploys it to GitHub Pages with `SITE_URL` and `BASE_PATH` taken from the Pages configuration. See `/docs/website/`.

## Provenance

Keep the original MIT `LICENSE` and preserve attribution. This is a fork customization of Astro Rocket; it is not affiliated with the upstream theme developer or with the Feishin project.
