/**
 * Brand values needed before `astro:env` exists.
 *
 * `astro.config.mjs` generates the favicon files in a build hook and
 * configures Starlight, and it cannot import `site.config.ts`, which reads
 * `astro:env/server` and so cannot be loaded at config time. Same constraint
 * as `site-url.ts`, same answer: keep the values in a plain module both sides
 * import, so they cannot drift.
 *
 * Change them here. `site.config.ts` and `project.config.ts` read from this file.
 *
 * Keep this module free of imports. A module that `astro.config.mjs` loads
 * and that imports another module (even a JSON file) closes Vite's module
 * runner before the build hooks' own dynamic imports run.
 */
export const SITE_NAME = 'Feishin Remote';

export const SITE_DESCRIPTION = 'Android remote control for a running Feishin music player.';

/** Source repository, used for links in the site and the docs. */
export const REPOSITORY_URL = 'https://github.com/rigerc/feishin-remote';

/** Browser toolbar colour and the app's amber accent. */
export const THEME_COLOR = '#e9b44c';

/**
 * The app's logo, relative to the website directory. The favicon generator
 * rasterises it; set it to `null` to fall back to a letter monogram.
 */
export const LOGO_SVG: string | null = '../assets/logo.svg';
