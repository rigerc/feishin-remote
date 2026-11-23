import { describe, it, expect, vi } from 'vitest';

// Exercise the nav config's locale resolution with i18n turned ON and two
// locales. The default locale stays at the site root; the secondary locale is
// prefixed and labels are translated via the dictionary. Guards the localized
// header/footer nav and logo wired up for #438.
vi.mock('@/config/i18n.config', () => ({
  default: {
    enabled: true,
    defaultLocale: 'en',
    locales: ['en', 'nl'],
    localeNames: { en: 'English', nl: 'Nederlands' },
    detectBrowserLocale: false,
  },
}));

import { getNavItems, getLogoHref, resolveNavItem, type NavItem } from '@/config/nav.config';

describe('nav config — locale resolution (en default, nl secondary)', () => {
  it('keeps default-locale hrefs at the site root', () => {
    const items = getNavItems('en');
    expect(items.map((i) => i.href)).toEqual(['/#features', '/#tour', '/#setup', '/docs/', '/support/']);
    expect(items.find((i) => i.label === 'Docs')?.href).toBe('/docs/');
  });

  it('prefixes plain secondary-locale paths with the locale', () => {
    const item: NavItem = { label: 'Docs', href: '/docs/', order: 1 };
    expect(resolveNavItem(item, 'nl').href).toBe('/nl/docs/');
  });

  it('translates labels via the dictionary (labelKey)', () => {
    // nl.json: nav.items.about = "Over"
    const item: NavItem = { label: 'About', href: '/about', order: 1, labelKey: 'nav.items.about' };
    expect(resolveNavItem(item, 'nl').label).toBe('Over');
    expect(resolveNavItem(item, 'en').label).toBe('About');
  });

  it('points the logo at the locale home', () => {
    expect(getLogoHref('en')).toBe('/');
    expect(getLogoHref('nl')).toBe('/nl');
  });

  it('never locale-prefixes external, mailto/tel, or anchor hrefs', () => {
    expect(
      resolveNavItem(
        { label: 'GitHub', href: 'https://github.com/x', order: 1, external: true },
        'nl'
      ).href
    ).toBe('https://github.com/x');
    expect(resolveNavItem({ label: 'Top', href: '#top', order: 1 }, 'nl').href).toBe('#top');
    expect(resolveNavItem({ label: 'Mail', href: 'mailto:a@b.com', order: 1 }, 'nl').href).toBe(
      'mailto:a@b.com'
    );
  });

  it('applies a per-locale override (label + path), still locale-prefixed', () => {
    const item: NavItem = {
      label: 'Contact',
      href: '/contact',
      order: 1,
      locales: { nl: { label: 'Neem contact op', href: '/contacteer' } },
    };
    expect(resolveNavItem(item, 'nl')).toEqual({
      label: 'Neem contact op',
      href: '/nl/contacteer',
      external: undefined,
    });
    // The default locale is unaffected by an nl-only override.
    expect(resolveNavItem(item, 'en')).toEqual({
      label: 'Contact',
      href: '/contact',
      external: undefined,
    });
  });

  it('falls back to the literal label when no labelKey is set', () => {
    expect(resolveNavItem({ label: 'Docs', href: '/docs', order: 1 }, 'nl').label).toBe('Docs');
  });
});
