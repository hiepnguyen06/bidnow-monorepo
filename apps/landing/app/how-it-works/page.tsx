import type { Metadata } from 'next'
import { Kicker } from '@/components/Card'
import { LinkButton } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { Section } from '@/components/home/Section'
import { AntiSnipeSimulator } from '@/components/how-it-works/AntiSnipeSimulator'
import { cn } from '@/lib/utils'

export const metadata: Metadata = {
  title: 'How it works',
  description:
    'The life of a BidNow auction from sign-up to payout, with a hands-on simulator of the anti-sniping rule.',
}

type Tone = 'brand' | 'warning' | 'neutral'

interface Step {
  when:  string
  title: string
  body:  string
  tone:  Tone
  link?: { href: string; label: string }
}

const STEPS: readonly Step[] = [
  { when: 'Before bidding', title: 'Sign up and verify', tone: 'brand',
    body: 'Register with an email and password, then enter the 6-digit code sent to you. The same account can buy and sell.' },
  { when: 'Seller', title: 'List an item', tone: 'brand',
    body: 'Set a starting price, a bid increment, a duration and, if you like, a Buy It Now price. The listing goes live without manual review.' },
  { when: 'Bidder', title: 'Place a first bid', tone: 'brand',
    body: "It must be at least the starting price. It also locks the auction's deposit in your wallet, and fails if your balance can't cover it." },
  { when: 'While live', title: 'Bid live, get outbid, bid again', tone: 'brand',
    body: 'Every later bid must reach the current price plus the increment. Whoever was leading hears they were outbid, and the seller hears about new bids.' },
  { when: 'Final minutes', title: 'Ending soon, and extended', tone: 'warning',
    body: 'Bidders are alerted 60 and 15 minutes before the end. A bid with under 120 seconds left adds 300 seconds to the clock.',
    link: { href: '#simulator', label: 'Try it below.' } },
  { when: 'At the end time', title: 'The auction closes itself', tone: 'brand',
    body: 'A scheduled job closes it. The highest bidder wins, and every other deposit goes back to its owner. With no bids, the seller is told the item went unsold.' },
  { when: 'Within 48 hours', title: 'The winner pays', tone: 'brand',
    body: 'The deposit counts toward the price; the rest comes from the wallet. A reminder goes out when 24 hours are left. On payment, the money moves to the seller.' },
  { when: 'If not paid', title: 'The deposit is forfeited', tone: 'neutral',
    body: 'The auction is marked failed and the winner loses the deposit.' },
]

const BADGE: Record<Tone, string> = {
  brand:   'bg-accent text-accent-foreground',
  warning: 'bg-[var(--color-warning-subtle)] text-[var(--color-warning-text)]',
  neutral: 'bg-muted text-muted-foreground',
}

export default function HowItWorksPage() {
  return (
    <>
      <PageHero
        eyebrow="How it works"
        title="The life of an auction, start to finish."
        description="Every step below happens on its own. All clocks run on server time in UTC, so every bidder sees the same countdown."
      />

      <Section id="timeline">
        <ol className="mx-auto max-w-3xl">
          {STEPS.map(({ when, title, body, tone, link }, i) => {
            const last = i === STEPS.length - 1
            return (
              <li key={title} className="flex gap-6">
                <div className="flex shrink-0 flex-col items-center">
                  <span className={cn('flex size-10 items-center justify-center rounded-full font-mono text-sm', BADGE[tone])}>
                    {i + 1}
                  </span>
                  {!last && <span className="w-0.5 flex-1 bg-[var(--color-border-default)]" aria-hidden="true" />}
                </div>
                <div className={cn('min-w-0', !last && 'pb-9')}>
                  <p
                    className={cn(
                      'mt-2 font-mono text-[length:var(--font-size-xs)] uppercase',
                      tone === 'warning' ? 'text-[var(--color-warning-text)]' : 'text-muted-foreground',
                    )}
                  >
                    {when}
                  </p>
                  <h2 className="mt-1.5 font-display text-[length:var(--font-size-xl)] font-medium">{title}</h2>
                  <p className="mt-2 leading-relaxed text-muted-foreground">
                    {body}
                    {link && (
                      <>
                        {' '}
                        <a href={link.href} className="text-[var(--color-text-brand)] underline-offset-4 hover:underline">
                          {link.label}
                        </a>
                      </>
                    )}
                  </p>
                </div>
              </li>
            )
          })}
        </ol>
      </Section>

      <Section id="simulator" tinted className="scroll-mt-28">
        <div className="flex flex-wrap items-start gap-12">
          <div className="min-w-0 flex-[1_1_360px]">
            <Kicker className="text-[var(--color-warning-text)]">Try it</Kicker>
            <h2 className="mt-3 font-display text-[length:clamp(1.75rem,3vw,2.5rem)] font-medium leading-[1.12]">
              Anti-sniping, hands on.
            </h2>
            <p className="mt-4 text-[length:var(--font-size-md)] leading-relaxed text-muted-foreground">
              Let the clock run, then bid. Any bid with less than 2:00 left adds 5:00 to the current end time. Wait it
              out and the auction closes.
            </p>
            <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
              This runs in your browser and only demonstrates the rule. Prices and the $50 increment are examples.
            </p>
          </div>
          <div className="min-w-0 flex-[1_1_520px]">
            <AntiSnipeSimulator />
          </div>
        </div>
      </Section>

      <Section>
        <div className="flex flex-wrap items-center justify-between gap-6">
          <h2 className="min-w-0 flex-[1_1_480px] font-display text-[length:var(--font-size-2xl)] font-medium leading-snug">
            Curious how the server keeps that clock honest when two bids arrive together?
          </h2>
          <LinkButton href="/engineering">Read the engineering notes</LinkButton>
        </div>
      </Section>
    </>
  )
}
