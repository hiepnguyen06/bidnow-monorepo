import type { ReactNode } from 'react'
import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface LinkButtonProps {
  href:      string
  children:  ReactNode
  /** `brand` for the main action; `outline-dark` for a secondary action on a dark band. */
  variant?:  'brand' | 'outline' | 'outline-dark'
  arrow?:    boolean
  className?: string
}

/** A large button that navigates. Internal paths go through next/link so the base path is applied. */
export function LinkButton({ href, children, variant = 'brand', arrow = false, className }: LinkButtonProps) {
  const internal = href.startsWith('/')
  return (
    <Button
      variant={variant === 'brand' ? 'brand' : 'outline'}
      size="xl"
      className={cn(
        'h-12 px-6',
        variant === 'outline-dark' && 'border-white/35 bg-transparent text-white hover:bg-white/10 dark:bg-transparent',
        className,
      )}
      render={internal ? <Link href={href} /> : <a href={href} />}
      nativeButton={false}
    >
      {children}
      {arrow && <ArrowRight className="size-4" aria-hidden="true" />}
    </Button>
  )
}

/** An inline "read more" link with a trailing arrow. */
export function MoreLink({ href, children, className }: { href: string; children: ReactNode; className?: string }) {
  const classes = cn(
    'inline-flex items-center gap-1.5 text-sm font-medium text-[var(--color-text-brand)] underline-offset-4 hover:underline',
    className,
  )
  const content = (
    <>
      {children}
      <ArrowRight className="size-4" aria-hidden="true" />
    </>
  )
  return href.startsWith('/') ? (
    <Link href={href} className={classes}>{content}</Link>
  ) : (
    <a href={href} className={classes}>{content}</a>
  )
}
