import { BidNowMark } from '@/components/shared/BidNowMark'
import { REPO_URL } from '@/lib/site'

export function SiteFooter() {
  return (
    <footer className="border-t bg-[var(--color-bg-elevated)]">
      <div className="mx-auto flex max-w-[var(--container-xl)] flex-col gap-3 px-4 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div className="flex items-center gap-2">
          <BidNowMark size={20} />
          <span className="text-sm text-muted-foreground">A portfolio project: real-time auctions on a microservice backend.</span>
        </div>
        <a href={REPO_URL} className="text-sm text-muted-foreground transition-colors hover:text-foreground">
          Source code on GitHub
        </a>
      </div>
    </footer>
  )
}
