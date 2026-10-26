import { Activity, Timer, Wallet } from 'lucide-react'
import { Card, Kicker } from '@/components/Card'
import { FactList, type Fact } from '@/components/FactList'
import { LinkButton, MoreLink } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { AuctionCardIllustration } from '@/components/home/AuctionCardIllustration'
import { Section, SectionHeading } from '@/components/home/Section'

const FACTS: readonly Fact[] = [
  { label: 'Anti-sniping window',    value: '< 120 s' },
  { label: 'Extension per late bid', value: '+300 s' },
  { label: 'Winner payment window',  value: '48 h' },
  { label: 'Backend modules',        value: '8 Spring Boot' },
]

const HIGHLIGHTS = [
  {
    icon:  Activity,
    title: 'Live bidding',
    body:  'The price, bid history and countdown are pushed to every viewer the moment a bid is accepted. No refresh, and guests can watch too.',
  },
  {
    icon:  Timer,
    title: 'Anti-sniping',
    body:  'Any accepted bid with under two minutes left pushes the end time back five minutes, as many times as it takes. The highest bid wins, not the fastest click.',
  },
  {
    icon:  Wallet,
    title: 'Deposits that protect sellers',
    body:  'Your first bid locks a deposit from your wallet. Lose, and it comes straight back. Win, and it counts toward the price you pay within 48 hours.',
  },
] as const

const STEPS = [
  { title: 'List',   body: 'A seller sets a starting price, bid increment, duration and an optional Buy It Now price.' },
  { title: 'Bid',    body: 'Each bid must beat the current price by at least the increment. The first one locks your deposit.' },
  { title: 'Extend', body: 'Late bids add five minutes. Bidders get alerts 60 and 15 minutes before the end.' },
  { title: 'Close',  body: 'The auction closes on its own. The highest bidder wins and every other deposit is refunded.' },
  { title: 'Pay',    body: 'The winner pays from their wallet within 48 hours, or forfeits the deposit.' },
] as const

const BID_PATH = [
  { name: 'Browser',     body: 'Next.js sends the bid over HTTPS' },
  { name: 'API gateway', body: "Checks the JWT, adds the user's identity" },
  { name: 'Bidding',     body: 'Pre-checks against Redis, locks the deposit' },
  { name: 'Auction',     body: 'Applies it under a row lock, extends if late' },
  { name: 'Kafka',       body: 'BidPlacedEvent after commit' },
  { name: 'Media',       body: 'Pushes the new price to every viewer over STOMP' },
] as const

const DEEP_DIVES = [
  { tag: 'Concurrency', title: 'Two bids, one price',        body: 'Why the auction row lock, not the cache, decides who leads.' },
  { tag: 'Scheduling',  title: 'Closing a clock that moves', body: 'Closure jobs that notice an extension and reschedule themselves.' },
  { tag: 'Money',       title: 'Money moves exactly once',   body: 'Idempotent deposit locks, per-refund transactions and dead-letter topics.' },
] as const

export default function HomePage() {
  return (
    <>
      <PageHero
        eyebrow="English auctions, live"
        title="Real-time auctions that play fair to the last second."
        description="BidNow is an English-auction marketplace. Prices and countdowns update live in every browser, a bid in the final two minutes adds five more, and a deposit keeps every bidder serious."
        aside={<AuctionCardIllustration />}
      >
        <div className="mt-9 flex flex-wrap gap-3">
          <LinkButton href="/features" arrow>Explore the features</LinkButton>
          <LinkButton href="/architecture" variant="outline-dark">See how it is built</LinkButton>
        </div>
        <FactList facts={FACTS} />
      </PageHero>

      <Section id="features">
        <SectionHeading eyebrow="For bidders and sellers" title="The rules of a good auction, enforced by the system." />
        <div className="grid gap-4 md:grid-cols-3">
          {HIGHLIGHTS.map(({ icon: Icon, title, body }) => (
            <Card key={title} className="p-7">
              <Icon className="size-7 text-[var(--color-text-brand)]" aria-hidden="true" />
              <h3 className="mt-5 font-display text-[length:var(--font-size-lg)] font-medium">{title}</h3>
              <p className="mt-2 leading-relaxed text-muted-foreground">{body}</p>
            </Card>
          ))}
        </div>
        <MoreLink href="/features" className="mt-8">All features, including Buy It Now and notifications</MoreLink>
      </Section>

      <Section id="how-it-works" tinted>
        <SectionHeading eyebrow="How an auction runs" title="From listing to payout in five steps." />
        <ol className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {STEPS.map(({ title, body }, i) => (
            <li key={title}>
              <Card className="h-full">
                <span className="font-mono text-sm text-[var(--color-text-brand)]">0{i + 1}</span>
                <h3 className="mt-3 text-lg font-semibold">{title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
              </Card>
            </li>
          ))}
        </ol>
        <MoreLink href="/how-it-works" className="mt-8">Walk through it and try the anti-sniping clock</MoreLink>
      </Section>

      <div className="dark bg-[var(--color-brand-900)] text-foreground">
        <Section id="under-the-hood">
          <SectionHeading
            eyebrow="Under the hood"
            title="One bid, from click to every screen."
            description="Microservices on Java 17 and Spring Boot 3.2, each with its own PostgreSQL database. Kafka carries the events; a STOMP WebSocket carries them to the browser."
          />
          <ol className="grid gap-3 sm:grid-cols-2 lg:grid-cols-6">
            {BID_PATH.map(({ name, body }, i) => (
              <li
                key={name}
                className={
                  i === BID_PATH.length - 1
                    ? 'rounded-xl border border-[var(--color-warning-default)] bg-[var(--color-bg-elevated)] p-4'
                    : 'rounded-xl border border-[var(--color-border-default)] bg-[var(--color-bg-elevated)] p-4'
                }
              >
                <span className="font-mono text-[length:var(--font-size-xs)] uppercase text-[var(--color-text-brand)]">{name}</span>
                <p className="mt-2 text-sm leading-relaxed">{body}</p>
              </li>
            ))}
          </ol>
          <div className="mt-10 flex flex-wrap gap-3">
            <LinkButton href="/architecture">Read the architecture</LinkButton>
            <LinkButton href="/engineering" variant="outline-dark">Engineering deep dives</LinkButton>
          </div>
        </Section>
      </div>

      <Section id="engineering">
        <SectionHeading eyebrow="Engineering notes" title="The hard parts, written up." />
        <div className="grid gap-4 md:grid-cols-3">
          {DEEP_DIVES.map(({ tag, title, body }) => (
            <Card key={title} className="p-7">
              <Kicker className="text-[var(--color-warning-text)]">{tag}</Kicker>
              <h3 className="mt-3 font-display text-[length:var(--font-size-lg)] font-medium">{title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
            </Card>
          ))}
        </div>
        <MoreLink href="/engineering" className="mt-8">Read all eight notes</MoreLink>
      </Section>
    </>
  )
}
