import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * The README makes checkable promises about this fork: the commands it tells
 * people to run, and the Node floor its tooling files agree on. Compare them
 * with the repository so they cannot drift quietly.
 */
const root = new URL('../../', import.meta.url);
const read = (rel: string) => readFileSync(fileURLToPath(new URL(rel, root)), 'utf8');

const readme = read('README.md');
const pkg = JSON.parse(read('package.json')) as {
  scripts: Record<string, string>;
  engines: { node: string };
};

/** pnpm subcommands that are not package scripts. */
const PNPM_BUILTINS = new Set(['install', 'exec', 'add', 'run']);

describe('what the README claims', () => {
  it('documents only pnpm scripts that exist', () => {
    const documented = [...readme.matchAll(/^\s*pnpm ([a-z][\w:-]*)/gm)].map((m) => m[1]);
    expect(documented.length).toBeGreaterThan(0);
    const missing = documented.filter((name) => !PNPM_BUILTINS.has(name) && !(name in pkg.scripts));
    expect(missing, `documented but not a script: ${missing.join(', ')}`).toEqual([]);
  });

  it('documents the quality gates', () => {
    for (const script of ['lint', 'check', 'build']) expect(readme).toContain(`pnpm ${script}`);
  });

  it('keeps .nvmrc on the major version the engines field asks for', () => {
    const floor = pkg.engines.node.replace(/^[^\d]*/, '');
    expect(read('.nvmrc').trim().replace(/^v/, '').split('.')[0]).toBe(floor.split('.')[0]);
  });

  it('names the engines floor in the Dockerfile comment', () => {
    const floor = pkg.engines.node.replace(/^[^\d]*/, '');
    expect(read('Dockerfile')).toContain(`\`engines\` floor of ${floor}`);
  });

  it('preserves the upstream MIT license and attribution', () => {
    expect(read('LICENSE')).toMatch(/MIT License/i);
    expect(readme).toContain('Astro Rocket');
  });
});
