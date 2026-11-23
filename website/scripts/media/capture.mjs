import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const baseUrl = (process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:4321').replace(/\/$/, '');
const outDir = resolve('media-output/screenshots');
await mkdir(outDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const views = [
  { name: 'home-desktop', route: '/', width: 1440, height: 900, mobile: false },
  { name: 'home-mobile', route: '/', width: 390, height: 844, mobile: true },
  { name: 'docs-desktop', route: '/docs/', width: 1440, height: 900, mobile: false },
  { name: 'docs-mobile', route: '/docs/', width: 390, height: 844, mobile: true },
];
try {
  for (const view of views) {
    const context = await browser.newContext({
      viewport: { width: view.width, height: view.height },
      deviceScaleFactor: 1,
      isMobile: view.mobile,
      hasTouch: view.mobile,
      colorScheme: 'dark',
      reducedMotion: 'reduce',
      locale: 'en-US',
    });
    const page = await context.newPage();
    const url = `${baseUrl}${view.route}`;
    const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 45_000 });
    if (!response || !response.ok()) throw new Error(`Capture failed: ${url} returned ${response?.status()}`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: resolve(outDir, `${view.name}.png`), fullPage: true, animations: 'disabled' });
    console.log(`Captured ${view.name}.png`);
    await context.close();
  }
} finally {
  await browser.close();
}
