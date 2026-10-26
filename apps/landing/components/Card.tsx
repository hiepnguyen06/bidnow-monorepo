import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

/** The bordered surface used for every card on the site. */
export function Card({ className, ...props }: ComponentProps<'div'>) {
  return (
    <div className={cn('rounded-xl border border-[var(--color-border-default)] bg-card p-6', className)} {...props} />
  )
}

/** Small mono label above a card title, e.g. "01 · CONCURRENCY". */
export function Kicker({ className, ...props }: ComponentProps<'p'>) {
  return (
    <p
      className={cn('m-0 font-mono text-[length:var(--font-size-xs)] font-medium uppercase text-[var(--color-text-brand)]', className)}
      {...props}
    />
  )
}

/** A bullet list with small brand-coloured dots. */
export function DotList({ items, className }: { items: readonly string[]; className?: string }) {
  return (
    <ul className={cn('grid gap-3 text-[length:var(--font-size-md)] leading-relaxed', className)}>
      {items.map((item) => (
        <li key={item} className="flex gap-3">
          <span className="mt-2.5 size-1.5 shrink-0 rounded-full bg-[var(--color-text-brand)]" aria-hidden="true" />
          {item}
        </li>
      ))}
    </ul>
  )
}
