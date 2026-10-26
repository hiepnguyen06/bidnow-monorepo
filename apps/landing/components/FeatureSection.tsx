import type { ReactNode } from 'react'
import { Kicker } from '@/components/Card'
import { cn } from '@/lib/utils'

interface FeatureSectionProps {
  id:        string
  kicker:    string
  title:     string
  children:  ReactNode
  /** The panel beside the text: a list, a table, a small figure. */
  aside?:    ReactNode
  tinted?:   boolean
}

/** One feature: text on the left, an explanatory panel on the right; they stack on narrow screens. */
export function FeatureSection({ id, kicker, title, children, aside, tinted = false }: FeatureSectionProps) {
  return (
    <section
      id={id}
      aria-labelledby={`${id}-title`}
      className={cn(
        'scroll-mt-28 py-16 md:py-24',
        tinted && 'border-y border-[var(--color-border-default)] bg-[var(--color-bg-elevated)]',
      )}
    >
      <div className="mx-auto flex w-full max-w-[var(--container-xl)] flex-wrap items-start gap-12 px-4 sm:px-6">
        <div className="min-w-0 flex-[1_1_420px]">
          <Kicker>{kicker}</Kicker>
          <h2
            id={`${id}-title`}
            className="mt-3 font-display text-[length:clamp(1.75rem,3vw,2.5rem)] font-medium leading-[1.12]"
          >
            {title}
          </h2>
          <div className="mt-4 text-[length:var(--font-size-md)] leading-relaxed text-muted-foreground">{children}</div>
        </div>
        {aside && <div className="min-w-0 flex-[1_1_400px]">{aside}</div>}
      </div>
    </section>
  )
}
