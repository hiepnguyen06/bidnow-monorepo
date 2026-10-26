import type { Metadata } from 'next'
import { Card, DotList } from '@/components/Card'
import { FeatureSection } from '@/components/FeatureSection'
import { LinkButton, MoreLink } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { Section } from '@/components/home/Section'

export const metadata: Metadata = {
  title: 'Features',
  description:
    'Live bidding, anti-sniping, Buy It Now, wallet deposits, notifications, selling and admin tools: what BidNow does for bidders and sellers.',
}

const SECTIONS = [
  { id: 'live',      label: 'Live bidding' },
  { id: 'antisnipe', label: 'Anti-sniping' },
  { id: 'buynow',    label: 'Buy It Now' },
  { id: 'wallet',    label: 'Wallet and deposits' },
  { id: 'notify',    label: 'Notifications' },
  { id: 'selling',   label: 'Selling' },
  { id: 'trust',     label: 'Accounts and admin' },
] as const

const BID_ERRORS = [
  { code: 'BID_TOO_LOW',              text: 'Too low, with the minimum you need to bid' },
  { code: 'BID_INSUFFICIENT_BALANCE', text: 'Not enough in your wallet, with what is available and what is required' },
  { code: 'BID_OWN_AUCTION',          text: 'Sellers cannot bid on their own listings' },
  { code: 'AUCTION_NOT_OPEN',         text: 'The auction has already ended or been cancelled' },
] as const

const ANTI_SNIPE = [
  { label: 'Window',    value: '<120 s' },
  { label: 'Extension', value: '+300 s' },
  { label: 'Cap',       value: 'None' },
] as const

const BUY_NOW_STEPS = [
  'The auction deposit is locked, just like a first bid.',
  'The auction ends at once, with the buyer as the winner.',
  'Everyone who had bid gets their deposit back.',
  'The buyer has the usual 48 hours to pay.',
] as const

const WALLET = [
  { title: 'Locked on your first bid', body: 'There is no separate sign-up step: your first bid on an auction registers you and locks its deposit.' },
  { title: 'Refunded if you lose',     body: "When the auction ends or is cancelled, every losing bidder's deposit returns to their wallet." },
  { title: 'Counted if you win',       body: "The winner's deposit goes toward the price. They pay the rest from their wallet within 48 hours, with a reminder when 24 hours are left." },
  { title: "Forfeited if you don't pay", body: 'Miss the window and the deposit is forfeited and the sale fails. Purchases show as pending payment, paid or forfeited.' },
] as const

const NOTIFICATION_TYPES = [
  'Outbid',
  'New bid on your auction',
  'Anti-sniping extension',
  'Ending soon',
  'Won, lost, unsold, cancelled',
  'Payment required and reminder',
  'Payment completed or failed',
  'Deposit refunded',
] as const

const LISTING_FIELDS = ['Title', 'Description', 'Category', 'Images', 'Starting price', 'Bid increment', 'Duration'] as const

const TRUST = [
  { title: 'Email verification',              body: 'Sign up with email and password, then confirm a 6-digit code. Only verified accounts can log in and bid.' },
  { title: 'Public profiles, private details', body: 'Visitors see a display name, avatar, bio, city, country and join date. Phone, address and preferences are never shown.' },
  { title: 'Admin tools',                     body: 'Admins can cancel auctions that break the rules, freeze wallets, issue one-off refunds, and review audit and email logs.' },
  { title: 'Everything audited',              body: 'Significant actions, admin ones included, are recorded with before and after snapshots.' },
] as const

const MONO_CODE = 'font-mono text-[0.85em]'

export default function FeaturesPage() {
  return (
    <>
      <PageHero
        eyebrow="Features"
        title="Everything an English auction needs, from first bid to payout."
        description="One account can buy and sell. Prices only go up, the highest bid wins, and the system enforces every rule so nobody has to referee."
      >
        <nav aria-label="On this page" className="mt-9 flex flex-wrap gap-2.5">
          {SECTIONS.map(({ id, label }) => (
            <a
              key={id}
              href={`#${id}`}
              className="flex min-h-11 items-center rounded-full border border-white/25 px-4 text-sm text-white transition-colors hover:bg-white/10"
            >
              {label}
            </a>
          ))}
        </nav>
      </PageHero>

      <FeatureSection
        id="live"
        kicker="01 · Live bidding"
        title="See every bid the instant it lands."
        aside={
          <Card className="bg-[var(--color-bg-elevated)] p-7">
            <p className="font-semibold">When a bid is refused, you are told why</p>
            <ul className="mt-4 grid gap-2.5">
              {BID_ERRORS.map(({ code, text }) => (
                <li key={code} className="rounded-lg border border-[var(--color-border-default)] bg-card px-4 py-3.5">
                  <span className="font-mono text-xs text-[var(--color-warning-text)]">{code}</span>
                  <p className="mt-1 text-sm">{text}</p>
                </li>
              ))}
            </ul>
          </Card>
        }
      >
        <p>
          Each auction page keeps a WebSocket open. When a bid is accepted, the new price, the bid history and the
          countdown change in every open browser, including for guests who are only watching. After a dropped
          connection the page fetches the auction again, so nothing is missed.
        </p>
        <DotList
          className="mt-6 text-foreground"
          items={[
            'The first bid may equal the starting price. Each later bid must be at least the current price plus the bid increment.',
            'Amounts take up to two decimal places.',
            '"My bids" lists every auction you are in, split into winning and outbid, soonest ending first.',
          ]}
        />
      </FeatureSection>

      <FeatureSection
        id="antisnipe"
        kicker="02 · Anti-sniping"
        title="A last-second bid buys everyone five more minutes."
        tinted
        aside={
          <div>
            <dl className="grid grid-cols-3 gap-3">
              {ANTI_SNIPE.map(({ label, value }) => (
                <Card key={label} className="p-5">
                  <dt className="text-sm text-muted-foreground">{label}</dt>
                  <dd className="mt-1.5 font-mono text-2xl">{value}</dd>
                </Card>
              ))}
            </dl>
            <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
              Both numbers are configuration, not code: <code className={MONO_CODE}>auction.anti-snipe.window-seconds</code>{' '}
              and <code className={MONO_CODE}>extension-seconds</code>.
            </p>
          </div>
        }
      >
        <p>
          If an accepted bid arrives with strictly less than 120 seconds left, the end time moves 300 seconds later.
          The extension is added to the current end time, not to the moment of the bid, and there is no limit on how
          many times it can happen. Every extension is recorded and broadcast live.
        </p>
        <MoreLink href="/how-it-works#simulator" className="mt-5">Try it in the simulator</MoreLink>
      </FeatureSection>

      <FeatureSection
        id="buynow"
        kicker="03 · Buy It Now"
        title="Skip the wait at the seller's price."
        aside={
          <ol className="grid gap-3">
            {BUY_NOW_STEPS.map((step, i) => (
              <li key={step}>
                <Card className="flex gap-4 px-5 py-4">
                  <span className="font-mono text-sm text-[var(--color-text-brand)]">{i + 1}</span>
                  <span>{step}</span>
                </Card>
              </li>
            ))}
          </ol>
        }
      >
        <p>
          A seller can set a Buy It Now price above the starting price. While the auction is live and the current bid
          is still below it, any buyer can take the item at that price, even after bidding has started.
        </p>
      </FeatureSection>

      <Section id="wallet" tinted className="scroll-mt-28">
        <div className="max-w-3xl">
          <p className="font-mono text-[length:var(--font-size-xs)] font-medium uppercase text-[var(--color-text-brand)]">
            04 · Wallet, deposits and payment
          </p>
          <h2 className="mt-3 font-display text-[length:clamp(1.75rem,3vw,2.5rem)] font-medium leading-[1.12]">
            Serious bidders, protected sellers.
          </h2>
          <p className="mt-4 text-[length:var(--font-size-md)] leading-relaxed text-muted-foreground">
            Every user has an internal wallet that shows total, available and locked funds. Taking part in an auction
            means putting a deposit on the line.
          </p>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {WALLET.map(({ title, body }) => (
            <Card key={title}>
              <h3 className="text-lg font-semibold">{title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
            </Card>
          ))}
        </div>
      </Section>

      <FeatureSection
        id="notify"
        kicker="05 · Notifications"
        title="Told what matters, without the noise."
        aside={
          <Card className="overflow-hidden p-0">
            <p className="border-b border-[var(--color-border-default)] bg-[var(--color-bg-elevated)] px-5 py-4 text-sm font-semibold">
              What you hear about
            </p>
            <ul className="grid grid-cols-2">
              {NOTIFICATION_TYPES.map((type) => (
                <li key={type} className="border-b border-[var(--color-border-default)] px-5 py-4 text-sm [&:nth-last-child(-n+2)]:border-b-0">
                  {type}
                </li>
              ))}
            </ul>
          </Card>
        }
      >
        <p>
          In-app notifications arrive live. An inbox keeps them with filters, search, read and unread, mark all as
          read, and bulk delete. Important events also go out by email, in English or Vietnamese.
        </p>
        <DotList
          className="mt-6 text-foreground"
          items={[
            'Outbid and new-bid alerts are batched. The first arrives at once, and later ones within 5 minutes are summed into one.',
            '"Ending soon" reaches bidders 60 and 15 minutes before the current end time.',
            'Email opt-out is respected, except for payment emails.',
          ]}
        />
      </FeatureSection>

      <FeatureSection
        id="selling"
        kicker="06 · Selling"
        title="List in minutes, track every sale."
        tinted
        aside={
          <Card className="p-7">
            <p className="text-sm font-semibold">A listing has</p>
            <ul className="mt-4 flex flex-wrap gap-2">
              {LISTING_FIELDS.map((field) => (
                <li key={field} className="rounded-full bg-accent px-3.5 py-2 text-sm text-accent-foreground">{field}</li>
              ))}
              <li className="rounded-full bg-[var(--color-warning-subtle)] px-3.5 py-2 text-sm text-[var(--color-warning-text)]">
                Buy It Now price (optional)
              </li>
            </ul>
          </Card>
        }
      >
        <p>
          Listings go live without waiting for review. Sellers follow their active and past auctions and see when the
          winner has paid. Images are stored privately and served through a CDN.
        </p>
      </FeatureSection>

      <Section id="trust" className="scroll-mt-28">
        <p className="font-mono text-[length:var(--font-size-xs)] font-medium uppercase text-[var(--color-text-brand)]">
          07 · Accounts and admin
        </p>
        <h2 className="mt-3 font-display text-[length:clamp(1.75rem,3vw,2.5rem)] font-medium leading-[1.12]">
          Verified people, accountable admins.
        </h2>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {TRUST.map(({ title, body }) => (
            <Card key={title}>
              <h3 className="text-lg font-semibold">{title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
            </Card>
          ))}
        </div>
      </Section>

      <section className="dark bg-[var(--color-brand-900)] text-foreground">
        <div className="mx-auto flex w-full max-w-[var(--container-xl)] flex-wrap items-center justify-between gap-8 px-4 py-16 sm:px-6">
          <div className="min-w-0 flex-[1_1_480px]">
            <p className="font-mono text-[length:var(--font-size-xs)] uppercase text-[var(--color-warning-text)]">Not built yet</p>
            <h2 className="mt-3 font-display text-[length:var(--font-size-2xl)] font-medium leading-snug">
              Auto-bidding is planned for phase 2, and an external payment gateway (Stripe or VNPay) after it.
            </h2>
            <p className="mt-3 text-muted-foreground">Today, wallet top-ups are simulated inside the platform.</p>
          </div>
          <LinkButton href="/about#status" variant="outline-dark">See project status</LinkButton>
        </div>
      </section>
    </>
  )
}
