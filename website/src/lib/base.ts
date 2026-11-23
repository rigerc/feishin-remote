/**
 * Base-path helpers for hosts that serve the site below a sub-path, such as
 * GitHub Pages project sites (`https://user.github.io/repo/`).
 *
 * Set `BASE_PATH=/repo` at build time (see `astro.config.mjs`). Astro rewrites
 * its own generated URLs, but hand-written root-absolute links (`/docs/`) must
 * go through `withBase`. With no base configured this is the identity function.
 */

/** The configured base without a trailing slash: `''` at the root, `'/repo'` below it. */
export const base: string = (import.meta.env?.BASE_URL ?? '/').replace(/\/+$/, '');

/** Prefix a root-absolute path with the base. Anything else is returned unchanged. */
export function withBase(path: string): string {
  if (!base || !path.startsWith('/') || path.startsWith('//')) return path;
  if (path === base || path.startsWith(`${base}/`) || path.startsWith(`${base}#`)) return path;
  return `${base}${path}`;
}
