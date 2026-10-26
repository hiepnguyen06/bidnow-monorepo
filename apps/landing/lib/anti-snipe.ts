/**
 * A browser-only model of the anti-sniping rule in auction-service, for the "How it works" simulator:
 * an accepted bid with strictly less than WINDOW_SECONDS left adds EXTENSION_SECONDS to the current end time.
 */

export const WINDOW_SECONDS    = 120
export const EXTENSION_SECONDS = 300

/** Example values for the simulator only. */
export const START_SECONDS = 150
export const START_PRICE   = 1000
export const INCREMENT     = 50
export const WAIT_SECONDS  = 30

/** How many log lines the simulator keeps, newest first. */
const LOG_SIZE = 6

export type SimEventKind = 'info' | 'bid' | 'extended' | 'closed'

export interface SimEvent {
  id:   number
  kind: SimEventKind
  text: string
}

export interface SimState {
  secondsLeft: number
  price:       number
  extensions:  number
  nextId:      number
  log:         readonly SimEvent[]
}

export function formatClock(seconds: number): string {
  const s = Math.max(0, seconds)
  const rest = s % 60
  return `${Math.floor(s / 60)}:${rest < 10 ? '0' : ''}${rest}`
}

export function formatMoney(amount: number): string {
  return amount.toLocaleString('en-US', { style: 'currency', currency: 'USD' })
}

export const isClosed = (s: SimState): boolean => s.secondsLeft <= 0

export const inExtensionWindow = (s: SimState): boolean => !isClosed(s) && s.secondsLeft < WINDOW_SECONDS

export const nextBidAmount = (s: SimState): number => s.price + INCREMENT

function withEvent(s: SimState, kind: SimEventKind, text: string): Pick<SimState, 'nextId' | 'log'> {
  return { nextId: s.nextId + 1, log: [{ id: s.nextId, kind, text }, ...s.log].slice(0, LOG_SIZE) }
}

export function initialState(): SimState {
  return {
    secondsLeft: START_SECONDS,
    price:       START_PRICE,
    extensions:  0,
    nextId:      1,
    log:         [{ id: 0, kind: 'info', text: `Auction live. ${formatClock(START_SECONDS)} left.` }],
  }
}

/** Places the minimum next bid. Does nothing once the auction has closed. */
export function placeBid(s: SimState): SimState {
  if (isClosed(s)) return s
  const amount = nextBidAmount(s)
  const at = formatClock(s.secondsLeft)

  if (s.secondsLeft < WINDOW_SECONDS) {
    const secondsLeft = s.secondsLeft + EXTENSION_SECONDS
    return {
      ...s,
      price: amount,
      secondsLeft,
      extensions: s.extensions + 1,
      ...withEvent(s, 'extended', `Bid ${formatMoney(amount)} at ${at} left. Extended to ${formatClock(secondsLeft)}.`),
    }
  }
  return { ...s, price: amount, ...withEvent(s, 'bid', `Bid ${formatMoney(amount)} at ${at} left. No extension.`) }
}

/** Runs the clock forward. Closes the auction when it reaches zero. */
export function letTimePass(s: SimState, seconds = WAIT_SECONDS): SimState {
  if (isClosed(s)) return s
  const secondsLeft = Math.max(0, s.secondsLeft - seconds)
  const event = secondsLeft === 0
    ? withEvent(s, 'closed', `Time is up. Sold at ${formatMoney(s.price)}.`)
    : withEvent(s, 'info', `${seconds} s passed. ${formatClock(secondsLeft)} left.`)
  return { ...s, secondsLeft, ...event }
}
