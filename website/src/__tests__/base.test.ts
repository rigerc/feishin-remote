import { describe, it, expect, vi, afterEach } from 'vitest';

/**
 * `withBase` keeps hand-written root-absolute links working when the site is
 * served below a sub-path (GitHub Pages project sites). BASE_URL is read when
 * the module loads, so each case stubs it and re-imports.
 */
const load = async (baseUrl: string) => {
  vi.resetModules();
  vi.stubEnv('BASE_URL', baseUrl);
  return import('@/lib/base');
};

afterEach(() => vi.unstubAllEnvs());

describe('withBase', () => {
  it('is the identity function at the site root', async () => {
    const { withBase, base } = await load('/');
    expect(base).toBe('');
    expect(withBase('/docs/')).toBe('/docs/');
    expect(withBase('/#features')).toBe('/#features');
  });

  it('prefixes root-absolute paths below a sub-path', async () => {
    const { withBase, base } = await load('/repo/');
    expect(base).toBe('/repo');
    expect(withBase('/')).toBe('/repo/');
    expect(withBase('/docs/media/')).toBe('/repo/docs/media/');
    expect(withBase('/#media')).toBe('/repo/#media');
  });

  it('leaves external, protocol-relative, anchor and relative URLs alone', async () => {
    const { withBase } = await load('/repo/');
    for (const url of ['https://example.com/x', '//cdn.example.com/x', '#top', 'mailto:a@b.c', './x', '../x']) {
      expect(withBase(url), url).toBe(url);
    }
  });

  it('does not prefix a path twice', async () => {
    const { withBase } = await load('/repo/');
    expect(withBase('/repo/docs/')).toBe('/repo/docs/');
    expect(withBase('/repo')).toBe('/repo');
  });
});
