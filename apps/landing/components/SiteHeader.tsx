import Link from 'next/link'
import { ArrowUpRight } from 'lucide-react'
import { BidNowMark } from '@/components/shared/BidNowMark'
import { SiteNav } from '@/components/SiteNav'
import { ThemeToggle } from '@/components/ThemeToggle'
import { REPO_URL } from '@/lib/site'

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-[var(--container-xl)] items-center justify-between gap-4 px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <BidNowMark size={24} />
          <span className="font-display text-lg font-bold leading-none tracking-[-0.06em]">bidnow</span>
        </Link>
        <SiteNav className="hidden md:flex" />
        <div className="flex items-center gap-2">
          <a
            href={REPO_URL}
            className="hidden items-center gap-1 text-sm text-muted-foreground transition-colors hover:text-foreground sm:flex"
          >
            Source
            <ArrowUpRight className="size-3.5" aria-hidden="true" />
          </a>
          <ThemeToggle />
        </div>
      </div>
      {/* Phones: the page links get their own scrollable row */}
      <SiteNav className="flex overflow-x-auto border-t px-2 md:hidden" />
    </header>
  )
}
