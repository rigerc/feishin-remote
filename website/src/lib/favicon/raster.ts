/**
 * Favicon generation — the raster half.
 *
 * `sharp` is a native Node module. It cannot load in workerd, so nothing here
 * may be imported by a page or by a prerendered endpoint when building for
 * Cloudflare. These are called from the `favicon-assets` integration in
 * `astro.config.mjs`, which runs in `astro:build:done` — always in Node, on
 * every adapter.
 */
import sharp from 'sharp';
import pngToIco from 'png-to-ico';
import { buildFaviconSvg } from './svg.ts';

/** Rasterise the favicon SVG to a square PNG buffer of the given pixel size. */
export async function renderFaviconPng(
  letter: string,
  bgColor: string,
  size: number,
  fgColor = '#ffffff'
): Promise<Buffer> {
  const svg = buildFaviconSvg(letter, bgColor, fgColor, size);
  return sharp(Buffer.from(svg)).resize(size, size).png().toBuffer();
}

/** Build a multi-size favicon.ico (16/32/48) from the outlined SVG. */
export async function renderFaviconIco(
  letter: string,
  bgColor: string,
  fgColor = '#ffffff'
): Promise<Buffer> {
  const pngs = await Promise.all(
    [16, 32, 48].map((s) => renderFaviconPng(letter, bgColor, s, fgColor))
  );
  return pngToIco(pngs);
}

/** Rasterise an existing SVG (the app logo) to a square PNG buffer. */
export async function renderSvgPng(svg: Buffer, size: number): Promise<Buffer> {
  return sharp(svg, { density: Math.max(72, Math.ceil((72 * size) / 64)) })
    .resize(size, size)
    .png()
    .toBuffer();
}

/** Build a multi-size favicon.ico (16/32/48) from an existing SVG. */
export async function renderSvgIco(svg: Buffer): Promise<Buffer> {
  return pngToIco(await Promise.all([16, 32, 48].map((s) => renderSvgPng(svg, s))));
}
