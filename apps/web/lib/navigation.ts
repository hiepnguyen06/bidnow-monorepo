export const ROUTES = {
  home:            '/',
  browse:          '/auctions',
  howItWorks:      '/how-it-works',
  faq:             '/faq',
  myBids:         '/my-bids',
  myAuctions:      '/seller/auctions',
  sell:            '/seller/auctions/new',
  wallet:          '/wallet',
  purchaseHistory: '/purchases',
  profile:         '/profile',
  settings:        '/settings',
  notifications:   '/notifications',
  login:           '/login',
  register:        '/register',
} as const

const LANDING_URL_PLACEHOLDER = 'https://bidnow-landing.example.com'

/** The showcase site's URL. Falls back to a placeholder while NEXT_PUBLIC_LANDING_URL is unset or blank. */
export function resolveLandingUrl(configured: string | undefined): string {
  const trimmed = configured?.trim()
  return trimmed ? trimmed : LANDING_URL_PLACEHOLDER
}

export const LANDING_URL = resolveLandingUrl(process.env.NEXT_PUBLIC_LANDING_URL)

/** Absolute URLs leave the app; everything else is an in-app path. */
export function isExternalHref(href: string): boolean {
  return /^https?:\/\//.test(href)
}

export interface NavLinkItem {
  label: string
  href:  string
}

/** The header's left-hand links, identical for guests, members and admins. */
export const NAV_LINKS: readonly NavLinkItem[] = [
  { label: 'Browse',       href: ROUTES.browse },
  { label: 'How it works', href: ROUTES.howItWorks },
  { label: 'FAQ',          href: ROUTES.faq },
  { label: 'About',        href: LANDING_URL },
]

/** A link is active on its own path and on any nested path ("/auctions/42" activates "/auctions"). */
export function isNavActive(pathname: string | null, href: string): boolean {
  if (!pathname) return false
  if (href === ROUTES.home) return pathname === ROUTES.home
  return pathname === href || pathname.startsWith(`${href}/`)
}
