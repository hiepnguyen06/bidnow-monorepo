import Link from 'next/link'
import { BidNowMark } from '@/components/shared/BidNowMark'
import { DOCS_URL, NAV_LINKS, REPO_URL } from '@/lib/site'

const LINK = 'text-sm text-muted-foreground transition-colors hover:text-foreground'

export function SiteFooter() {
  return (
    <footer className="border-t bg-[var(--color-bg-elevated)]">
      <div className="mx-auto flex max-w-[var(--container-xl)] flex-col gap-6 px-4 py-10 sm:px-6 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2">
          <BidNowMark size={20} />
          <span className="text-sm text-muted-foreground">BidNow · built by Hiep Nguyen and Khoa Ly</span>
        </div>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-5 gap-y-2">
          {NAV_LINKS.map(({ label, href }) => (
            <Link key={href} href={href} className={LINK}>
              {label}
            </Link>
          ))}
          <a href={REPO_URL} className={LINK}>GitHub</a>
          <a href={DOCS_URL} className={LINK}>Docs</a>
        </nav>
      </div>
    </footer>
  )
}
