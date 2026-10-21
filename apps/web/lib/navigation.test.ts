import { describe, expect, it } from 'vitest'
import { LANDING_URL, NAV_LINKS, ROUTES, isExternalHref, isNavActive, resolveLandingUrl } from './navigation'

describe('isNavActive', () => {
  it('matches the exact path', () => {
    expect(isNavActive('/auctions', '/auctions')).toBe(true)
  })

  it('matches nested paths on a segment boundary', () => {
    expect(isNavActive('/auctions/42', '/auctions')).toBe(true)
  })

  it('does not match a sibling that only shares a prefix', () => {
    expect(isNavActive('/auctions-archive', '/auctions')).toBe(false)
  })

  it('only matches home exactly', () => {
    expect(isNavActive('/', '/')).toBe(true)
    expect(isNavActive('/auctions', '/')).toBe(false)
  })

  it('is inactive when the pathname is unknown', () => {
    expect(isNavActive(null, '/auctions')).toBe(false)
  })
})

describe('nav links', () => {
  it('lists Browse, How it works, FAQ and About, in that order', () => {
    expect(NAV_LINKS.map((l) => l.label)).toEqual(['Browse', 'How it works', 'FAQ', 'About'])
    expect(NAV_LINKS.map((l) => l.href)).toEqual([ROUTES.browse, ROUTES.howItWorks, ROUTES.faq, LANDING_URL])
  })

  it('has no standalone Live link', () => {
    expect(NAV_LINKS.map((l) => l.label)).not.toContain('Live')
  })

  it('leaves member-only pages to the account menu', () => {
    expect(NAV_LINKS.map((l) => l.href)).not.toContain(ROUTES.myBids)
  })
})

describe('landing site link', () => {
  it('uses the configured URL when one is set', () => {
    expect(resolveLandingUrl('https://landing.example.org')).toBe('https://landing.example.org')
  })

  it('falls back to the placeholder when unset or blank, never "undefined"', () => {
    for (const value of [undefined, '', '   ']) {
      const url = resolveLandingUrl(value)
      expect(url).toMatch(/^https:\/\//)
      expect(url).not.toContain('undefined')
    }
  })

  it('points the About nav link at the landing site', () => {
    expect(NAV_LINKS.find((l) => l.label === 'About')?.href).toBe(LANDING_URL)
  })

  it('treats absolute URLs as external and app paths as internal', () => {
    expect(isExternalHref(LANDING_URL)).toBe(true)
    expect(isExternalHref(ROUTES.browse)).toBe(false)
  })
})
