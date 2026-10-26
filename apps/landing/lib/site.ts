export const REPO_URL = 'https://github.com/hiepnguyen06/bidnow-monorepo'
export const DOCS_URL = `${REPO_URL}/tree/main/docs`

/** A file in the repository on GitHub, e.g. `docs/architecture.md`. */
export function repoFileUrl(path: string): string {
  return `${REPO_URL}/blob/main/${path}`
}

export interface NavLink {
  label: string
  href:  string
}

export const NAV_LINKS: readonly NavLink[] = [
  { label: 'Features',     href: '/features' },
  { label: 'How it works', href: '/how-it-works' },
  { label: 'Architecture', href: '/architecture' },
  { label: 'Engineering',  href: '/engineering' },
  { label: 'About',        href: '/about' },
]

/** True when `pathname` is `href` or a page below it. Trailing slashes (from `trailingSlash: true`) are ignored. */
export function isActivePath(pathname: string, href: string): boolean {
  const path = pathname.replace(/\/+$/, '') || '/'
  return path === href || path.startsWith(`${href}/`)
}
