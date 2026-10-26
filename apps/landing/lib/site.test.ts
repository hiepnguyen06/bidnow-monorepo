import { describe, expect, it } from 'vitest'
import { NAV_LINKS, isActivePath, repoFileUrl } from './site'

describe('isActivePath', () => {
  it('matches the page with or without a trailing slash', () => {
    expect(isActivePath('/features', '/features')).toBe(true)
    expect(isActivePath('/features/', '/features')).toBe(true)
  })

  it('does not match a different page sharing a prefix', () => {
    expect(isActivePath('/featuresx', '/features')).toBe(false)
    expect(isActivePath('/', '/features')).toBe(false)
  })
})

describe('repoFileUrl', () => {
  it('points at the main branch', () => {
    expect(repoFileUrl('docs/architecture.md')).toBe(
      'https://github.com/hiepnguyen06/bidnow-monorepo/blob/main/docs/architecture.md',
    )
  })
})

describe('NAV_LINKS', () => {
  it('uses unique, absolute paths', () => {
    const hrefs = NAV_LINKS.map((l) => l.href)
    expect(new Set(hrefs).size).toBe(hrefs.length)
    for (const href of hrefs) expect(href).toMatch(/^\/[a-z-]+$/)
  })
})
