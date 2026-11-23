import { chromium } from 'playwright';
import { mkdir, copyFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const baseUrl = (process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:4321').replace(/\/$/, '');
const videos = resolve('media-output/videos');
const raw = resolve('media-output/raw');
await mkdir(videos, { recursive: true });
await mkdir(raw, { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  deviceScaleFactor: 1,
  colorScheme: 'dark',
  reducedMotion: 'reduce',
  recordVideo: { dir: raw, size: { width: 1280, height: 720 } },
});
const page = await context.newPage();
let videoPath;
try {
  const response = await page.goto(`${baseUrl}/`, { waitUntil: 'networkidle', timeout: 45_000 });
  if (!response?.ok()) throw new Error(`Video source returned ${response?.status()}`);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(1200);
  for (const selector of ['#features', '#tour', '#setup', '#faq']) {
    await page.locator(selector).waitFor();
    await page.evaluate(async (targetSelector) => {
      const element = document.querySelector(targetSelector);
      if (!element) return;
      const target = window.scrollY + element.getBoundingClientRect().top - 90;
      const start = window.scrollY;
      const startTime = performance.now();
      await new Promise((done) => {
        const frame = (now) => {
          const t = Math.min(1, (now - startTime) / 850);
          const eased = t * t * (3 - 2 * t);
          window.scrollTo(0, start + (target - start) * eased);
          if (t < 1) requestAnimationFrame(frame);
          else done();
        };
        requestAnimationFrame(frame);
      });
    }, selector);
    await page.waitForTimeout(900);
  }
  await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
  await page.waitForTimeout(1200);
  videoPath = await page.video().path();
} finally {
  await context.close();
  await browser.close();
}
const webm = resolve(videos, 'walkthrough.webm');
await copyFile(videoPath, webm);
const mp4 = resolve(videos, 'walkthrough.mp4');
const ffmpeg = spawnSync('ffmpeg', [
  '-hide_banner', '-loglevel', 'error', '-y', '-i', webm,
  '-vf', 'fps=30,format=yuv420p', '-c:v', 'libx264', '-preset', 'medium',
  '-crf', '24', '-movflags', '+faststart', '-an', mp4,
], { stdio: 'inherit' });
if (ffmpeg.error) throw new Error(`FFmpeg is required to encode MP4: ${ffmpeg.error.message}`);
if (ffmpeg.status !== 0) throw new Error(`FFmpeg failed with exit code ${ffmpeg.status}`);
console.log('Generated media-output/videos/walkthrough.mp4');
