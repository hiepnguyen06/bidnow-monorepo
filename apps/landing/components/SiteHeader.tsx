import Link from 'next/link'
import { BidNowMark } from '@/components/shared/BidNowMark'
import { REPO_URL } from '@/lib/site'

const LINKS = [
  { label: 'Architecture', href: '#architecture' },
  { label: 'Source', href: REPO_URL },
] as const

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-[var(--container-xl)] items-center justify-between px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <BidNowMark size={24} />
          <span className="font-display text-lg font-bold leading-none tracking-[-0.06em]">bidnow</span>
        </Link>
        <nav aria-label="Primary" className="flex items-center gap-5 text-sm text-muted-foreground">
          {LINKS.map(({ label, href }) => (
            <a key={href} href={href} className="transition-colors hover:text-foreground">
              {label}
            </a>
          ))}
        </nav>
      </div>
    </header>
  )
}
