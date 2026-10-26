import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

interface PageHeroProps {
  eyebrow:      string
  title:        string
  description?: ReactNode
  /** Buttons, chips or a fact list under the lead-in. */
  children?:    ReactNode
  /** Something to show beside the text on wide screens, e.g. an illustration. */
  aside?:       ReactNode
  className?:   string
}

/** The dark band that opens every page. It stays dark in both themes. */
export function PageHero({ eyebrow, title, description, children, aside, className }: PageHeroProps) {
  return (
    <section className="dark bg-[var(--color-brand-900)] text-foreground">
      <div className={cn('mx-auto w-full max-w-[var(--container-xl)] px-4 pb-16 pt-16 sm:px-6 md:pb-20 md:pt-24', className)}>
        <div className="flex flex-wrap items-center gap-x-14 gap-y-12">
          <div className="min-w-0 flex-[999_1_520px]">
            <p className="flex items-center gap-2.5 font-mono text-[length:var(--font-size-xs)] font-medium uppercase text-muted-foreground">
              <span className="size-2 rounded-full bg-[var(--color-warning-default)]" aria-hidden="true" />
              {eyebrow}
            </p>
            <h1 className="mt-6 max-w-4xl font-display text-[length:clamp(2.5rem,6vw,4.25rem)] font-medium leading-[1.05] text-balance">
              {title}
            </h1>
            {description && (
              <p className="mt-7 max-w-2xl text-[length:var(--font-size-md)] leading-relaxed text-muted-foreground text-pretty">
                {description}
              </p>
            )}
          </div>
          {aside && <div className="min-w-0 max-w-[460px] flex-[1_1_360px]">{aside}</div>}
        </div>
        {children}
      </div>
    </section>
  )
}
