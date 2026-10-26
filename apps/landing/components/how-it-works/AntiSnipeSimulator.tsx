'use client'

import { useState } from 'react'
import {
  INCREMENT,
  WAIT_SECONDS,
  formatClock,
  formatMoney,
  inExtensionWindow,
  initialState,
  isClosed,
  letTimePass,
  nextBidAmount,
  placeBid,
  type SimEventKind,
} from '@/lib/anti-snipe'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

/** Longest clock the progress bar shows as full: the start time plus one extension. */
const BAR_FULL_SECONDS = 450

const EVENT_TONE: Record<SimEventKind, string> = {
  info:     'text-muted-foreground',
  bid:      'text-foreground',
  extended: 'text-[var(--color-warning-text)]',
  closed:   'text-[var(--color-text-brand)]',
}

/** Hands-on demo of the anti-sniping rule. Everything runs in the browser; prices are examples. */
export function AntiSnipeSimulator() {
  const [state, setState] = useState(initialState)
  const closed = isClosed(state)
  const inWindow = inExtensionWindow(state)
  const barPercent = Math.min(100, Math.round((state.secondsLeft / BAR_FULL_SECONDS) * 100))

  return (
    <div className="dark rounded-2xl bg-[var(--color-brand-900)] p-6 text-foreground sm:p-7">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className="font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">Simulated auction</span>
        {inWindow && (
          <span className="rounded-full bg-[var(--color-warning-subtle)] px-3 py-1.5 text-sm text-[var(--color-warning-text)]">
            Inside the 2-minute window
          </span>
        )}
        {closed && <span className="rounded-full bg-muted px-3 py-1.5 text-sm">Closed</span>}
      </div>

      <dl className="mt-6 flex flex-wrap gap-x-10 gap-y-4">
        <div>
          <dt className="text-sm text-muted-foreground">Time left</dt>
          <dd
            className={cn(
              'mt-1.5 font-mono text-[length:clamp(1.5rem,3.2vw,2.25rem)] font-medium tabular-nums',
              inWindow && 'text-[var(--color-warning-text)]',
              closed && 'text-muted-foreground',
            )}
          >
            {formatClock(state.secondsLeft)}
          </dd>
        </div>
        <div>
          <dt className="text-sm text-muted-foreground">Current bid</dt>
          <dd className="mt-1.5 font-mono text-[length:clamp(1.5rem,3.2vw,2.25rem)] font-medium tabular-nums">{formatMoney(state.price)}</dd>
        </div>
        <div>
          <dt className="text-sm text-muted-foreground">Extensions</dt>
          <dd className="mt-1.5 font-mono text-[length:clamp(1.5rem,3.2vw,2.25rem)] font-medium tabular-nums">{state.extensions}</dd>
        </div>
      </dl>

      <div className="mt-5 h-2 overflow-hidden rounded-full bg-muted" aria-hidden="true">
        <div
          className={cn(
            'h-full rounded-full transition-[width] duration-300',
            inWindow ? 'bg-[var(--color-warning-default)]' : 'bg-[var(--color-text-brand)]',
          )}
          style={{ width: `${barPercent}%` }}
        />
      </div>

      <div className="mt-6 flex flex-wrap gap-2.5">
        <Button variant="brand" size="xl" className="h-12 px-5" disabled={closed} onClick={() => setState(placeBid)}>
          {closed ? 'Auction closed' : `Bid ${formatMoney(nextBidAmount(state))}`}
        </Button>
        <Button
          variant="outline"
          size="xl"
          className="h-12 px-5"
          disabled={closed}
          onClick={() => setState((s) => letTimePass(s))}
        >
          Let {WAIT_SECONDS} s pass
        </Button>
        <Button variant="ghost" size="xl" className="h-12 px-5" onClick={() => setState(initialState())}>
          Reset
        </Button>
      </div>

      <div className="mt-6 border-t border-[var(--color-border-default)] pt-4">
        <p className="text-sm text-muted-foreground">Event log</p>
        <ul aria-live="polite" className="mt-2.5 grid gap-2 font-mono text-sm leading-relaxed">
          {state.log.map((event) => (
            <li key={event.id} className={EVENT_TONE[event.kind]}>
              {event.text}
            </li>
          ))}
        </ul>
      </div>
      <p className="sr-only">Each bid adds {formatMoney(INCREMENT)}.</p>
    </div>
  )
}
