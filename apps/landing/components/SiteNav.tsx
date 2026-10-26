'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { NAV_LINKS, isActivePath } from '@/lib/site'
import { cn } from '@/lib/utils'

/** The page links, with the current page marked. */
export function SiteNav({ className }: { className?: string }) {
  const pathname = usePathname()

  return (
    <nav aria-label="Primary" className={cn('items-center gap-1 text-sm', className)}>
      {NAV_LINKS.map(({ label, href }) => {
        const active = isActivePath(pathname, href)
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? 'page' : undefined}
            className={cn(
              'shrink-0 rounded-md px-3 py-2 transition-colors hover:text-foreground',
              active ? 'font-medium text-foreground' : 'text-muted-foreground',
            )}
          >
            {label}
          </Link>
        )
      })}
    </nav>
  )
}
