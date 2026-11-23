/**
 * Keeps the colour-theme set tied to the files on disk.
 *
 * The set lives in four places: the files in src/styles/themes/, the @import
 * list in tokens/colors.css, the allowlist the BaseLayout bootstrap validates
 * sessionStorage against, and the registry the pickers read. This compares them
 * so a theme cannot be added to one and missed in another.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

import { colourThemes, selectorThemes } from '../lib/themes';

const COUNT = colourThemes.length;
const IDS = colourThemes.map((t) => t.id);
const read = (p: string) => readFileSync(join(process.cwd(), p), 'utf8');
const norm = (s: string) => s.replace(/\s+/g, ' ').trim();

describe('colour themes', () => {
  it('ids are unique and lower-case', () => {
    expect(new Set(IDS).size).toBe(COUNT);
    for (const id of IDS) expect(id).toMatch(/^[a-z]+$/);
  });

  it('every theme has a file, and every file is a theme', () => {
    const onDisk = readdirSync(join(process.cwd(), 'src/styles/themes'))
      .filter((f) => f.endsWith('.css'))
      .map((f) => f.replace('.css', ''));
    expect(onDisk.sort()).toEqual([...IDS].sort());
  });

  it('every theme file scopes itself to its own id', () => {
    for (const id of IDS) {
      const css = read(`src/styles/themes/${id}.css`);
      expect(css, id).toContain(`html[data-theme="${id}"]`);
      expect(css, id).toContain(`html.dark[data-theme="${id}"]`);
    }
  });

  it('every theme file defines the full brand scale', () => {
    const steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    for (const id of IDS) {
      const css = read(`src/styles/themes/${id}.css`);
      for (const step of steps) {
        expect(css, `${id} → --brand-${step}`).toMatch(
          new RegExp(`--brand-${step}:\\s*oklch\\(`)
        );
      }
    }
  });

  it('the swatch colour matches the palette brand-500', () => {
    for (const theme of colourThemes) {
      const css = read(`src/styles/themes/${theme.id}.css`);
      const match = /--brand-500:\s*(oklch\([^)]*\))/.exec(css);
      expect(match, `${theme.id} has no --brand-500`).not.toBeNull();
      expect(norm(theme.color), theme.id).toBe(norm(match![1]));
    }
  });

  it('colors.css imports exactly the registered themes', () => {
    const imported = [...read('src/styles/tokens/colors.css').matchAll(
      /@import\s+'\.\.\/themes\/([a-z0-9-]+)\.css'/g
    )].map((m) => m[1]);
    expect(imported.sort()).toEqual([...IDS].sort());
  });

  it('the bootstrap allowlist matches the registry', () => {
    const match = /const COLOR_THEMES = \[([^\]]*)\]/.exec(read('src/layouts/BaseLayout.astro'));
    expect(match, 'COLOR_THEMES not found in BaseLayout').not.toBeNull();
    const allowed = [...match![1].matchAll(/'([a-z0-9-]+)'/g)].map((m) => m[1]);
    expect(allowed.sort()).toEqual([...IDS].sort());
  });

  it('the default the layout seeds is one of the themes', () => {
    const match = /<html[^>]*\sdata-theme="([a-z0-9-]+)"/.exec(read('src/layouts/BaseLayout.astro'));
    expect(match, 'no seeded data-theme on <html>').not.toBeNull();
    expect(IDS).toContain(match![1]);
  });

  it('the base scale in primitives.css matches that default', () => {
    const fallback = /<html[^>]*\sdata-theme="([a-z0-9-]+)"/.exec(read('src/layouts/BaseLayout.astro'))![1];
    const base = /--brand-500:\s*(oklch\([^)]*\))/.exec(read('src/styles/tokens/primitives.css'));
    const theme = /--brand-500:\s*(oklch\([^)]*\))/.exec(read(`src/styles/themes/${fallback}.css`));
    expect(norm(base![1])).toBe(norm(theme![1]));
  });

  it('no per-theme exception names a theme that is gone', () => {
    for (const file of ['src/styles/global.css', 'src/components/ui/form/Button/Button.astro']) {
      for (const m of read(file).matchAll(/\[data-theme="([a-z0-9-]+)"\]/g)) {
        expect(IDS, `${file} → ${m[1]}`).toContain(m[1]);
      }
    }
  });

  it('every registered theme is offered in the pickers', () => {
    expect(selectorThemes).toHaveLength(COUNT);
  });
});
