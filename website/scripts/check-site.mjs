import { access, stat } from 'node:fs/promises';
import { resolve } from 'node:path';

const roots = ['dist', '.vercel/output/static'];
const routes = [
  'index.html',
  'privacy/index.html',
  'support/index.html',
  '404.html',
  'docs/index.html',
  'docs/getting-started/index.html',
  'docs/using-the-app/index.html',
  'docs/troubleshooting/index.html',
  'docs/security/index.html',
  'docs/development/index.html',
  'docs/releases/index.html',
  'docs/website/index.html',
  'logo.svg',
  'favicon.svg',
  'sitemap-index.xml',
];
// App captures from tool/media.sh; the homepage links all of them.
const media = ['playing.webp', 'library.webp', 'queue.webp', 'tour.mp4', 'tour-poster.webp'];

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

const root = (
  await Promise.all(roots.map(async (root) => ({ root, ok: await exists(resolve(root, 'index.html')) })))
).find((x) => x.ok)?.root;
if (!root) throw new Error('No built landing page found. Run pnpm build first.');
for (const route of routes) {
  if (!(await exists(resolve(root, route)))) throw new Error(`Missing route: ${root}/${route}`);
  console.log(`OK: /${route}`);
}
for (const file of media) {
  const path = resolve(root, 'media', file);
  if (!(await exists(path)) || (await stat(path)).size === 0) {
    throw new Error(`Missing app media: ${root}/media/${file}. Run tool/media.sh before building.`);
  }
  console.log(`OK: /media/${file}`);
}
for (const obsolete of ['blog/index.html', 'projects/index.html', 'services/index.html', 'about/index.html', 'contact/index.html']) {
  if (await exists(resolve(root, obsolete))) throw new Error(`Obsolete demo route still exists: ${obsolete}`);
}
console.log('Feishin Remote routes verified.');
