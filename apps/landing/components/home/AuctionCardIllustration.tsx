import { ImageIcon } from 'lucide-react'

/**
 * A static picture of a live auction right after an anti-sniping extension: a bid with 1:41 left
 * moved the end five minutes later, so 6:41 remain. Values are examples.
 */
export function AuctionCardIllustration() {
  return (
    <figure className="m-0">
      <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-bg-elevated)] p-6">
        <div className="flex items-center justify-between gap-3">
          <span className="font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">Live auction</span>
          <span className="flex items-center gap-1.5 text-sm text-[var(--color-warning-text)]">
            <span className="size-1.5 rounded-full bg-[var(--color-warning-default)]" aria-hidden="true" />
            Extended +5:00
          </span>
        </div>
        <div className="mt-5 flex h-40 items-center justify-center rounded-xl bg-muted text-muted-foreground">
          <ImageIcon className="size-8" aria-hidden="true" />
        </div>
        <p className="mt-4 font-display text-[length:var(--font-size-lg)] font-medium">Vintage film camera</p>
        <dl className="mt-4 grid grid-cols-2 gap-4">
          <div>
            <dt className="text-sm text-muted-foreground">Current bid</dt>
            <dd className="mt-1 font-mono text-2xl font-medium">$1,250.00</dd>
          </div>
          <div>
            <dt className="text-sm text-muted-foreground">Ends in</dt>
            <dd className="mt-1 font-mono text-2xl font-medium text-[var(--color-warning-text)]">6:41</dd>
          </div>
        </dl>
        <p className="mt-4 rounded-lg bg-muted px-3.5 py-3 text-sm leading-relaxed">
          A bid landed with 1:41 left, so the clock moved five minutes later for everyone watching.
        </p>
        <div className="mt-4 flex h-12 items-center justify-center rounded-lg bg-brand-600 font-medium text-white" aria-hidden="true">
          Bid $1,300.00
        </div>
      </div>
      <figcaption className="mt-2.5 text-center text-xs text-muted-foreground">Illustration. Values are examples.</figcaption>
    </figure>
  )
}
