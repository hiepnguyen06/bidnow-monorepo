import { describe, expect, it } from 'vitest'
import {
  EXTENSION_SECONDS,
  INCREMENT,
  START_PRICE,
  formatClock,
  formatMoney,
  inExtensionWindow,
  initialState,
  isClosed,
  letTimePass,
  placeBid,
  type SimState,
} from './anti-snipe'

const at = (secondsLeft: number): SimState => ({ ...initialState(), secondsLeft })

describe('formatClock', () => {
  it('pads seconds and never goes negative', () => {
    expect(formatClock(150)).toBe('2:30')
    expect(formatClock(65)).toBe('1:05')
    expect(formatClock(-3)).toBe('0:00')
  })
})

describe('formatMoney', () => {
  it('formats US dollars with cents', () => {
    expect(formatMoney(1250)).toBe('$1,250.00')
  })
})

describe('placeBid', () => {
  it('raises the price by one increment', () => {
    expect(placeBid(at(600)).price).toBe(START_PRICE + INCREMENT)
  })

  it('does not extend with 120 s or more left', () => {
    const next = placeBid(at(120))
    expect(next.secondsLeft).toBe(120)
    expect(next.extensions).toBe(0)
  })

  it('adds 300 s to the current end time with strictly less than 120 s left', () => {
    const next = placeBid(at(119))
    expect(next.secondsLeft).toBe(119 + EXTENSION_SECONDS)
    expect(next.extensions).toBe(1)
    expect(next.log[0].kind).toBe('extended')
  })

  it('has no cap on extensions', () => {
    let s = at(10)
    for (let i = 0; i < 5; i++) s = placeBid(letTimePass(s, s.secondsLeft - 10))
    expect(s.extensions).toBe(5)
  })

  it('ignores bids once closed', () => {
    const closed = at(0)
    expect(placeBid(closed)).toBe(closed)
  })
})

describe('letTimePass', () => {
  it('counts down and closes at zero', () => {
    const s = letTimePass(at(20), 30)
    expect(s.secondsLeft).toBe(0)
    expect(isClosed(s)).toBe(true)
    expect(s.log[0].kind).toBe('closed')
  })

  it('reports the extension window only while open', () => {
    expect(inExtensionWindow(at(150))).toBe(false)
    expect(inExtensionWindow(at(90))).toBe(true)
    expect(inExtensionWindow(at(0))).toBe(false)
  })

  it('keeps the log short and the ids unique', () => {
    let s = initialState()
    for (let i = 0; i < 10; i++) s = placeBid(s)
    expect(s.log).toHaveLength(6)
    expect(new Set(s.log.map((e) => e.id)).size).toBe(6)
  })
})
