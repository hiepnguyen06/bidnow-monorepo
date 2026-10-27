import type { ReactNode } from 'react'
import type { Metadata } from 'next'
import Image from 'next/image'
import { ArrowDown } from 'lucide-react'
import { Card, Kicker } from '@/components/Card'
import { FactList, type Fact } from '@/components/FactList'
import { LinkButton, MoreLink } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { Section, SectionHeading } from '@/components/home/Section'
import { repoFileUrl } from '@/lib/site'
import { cn } from '@/lib/utils'

export const metadata: Metadata = {
  title: 'Architecture',
  description:
    'How BidNow is built: eight Spring Boot modules, the life of a bid, Kafka events, live WebSocket updates, and the three-tier AWS deployment behind it.',
}

const FACTS: readonly Fact[] = [
  { label: 'Backend modules',    value: '8' },
  { label: 'Database ownership', value: '1 per service' },
  { label: 'Service to service', value: 'Feign + Kafka' },
  { label: 'Live updates',       value: 'STOMP / WS' },
]

interface Chip {
  name:    string
  detail:  string
  strong?: boolean
}

const LAYERS: readonly { label: string; chips: readonly Chip[] }[] = [
  {
    label: 'Client',
    chips: [{ name: 'Next.js 16 web app', detail: 'HTTPS + STOMP over WebSocket' }],
  },
  {
    label: 'Edge',
    chips: [
      { name: 'api-gateway',       detail: 'Spring Cloud Gateway: validates the JWT, routes explicit /api/v1 paths', strong: true },
      { name: 'discovery-service', detail: 'Eureka registry' },
    ],
  },
]

const DOMAIN_SERVICES: readonly Chip[] = [
  { name: 'identity', detail: 'Sign-up, email OTP, login, JWT issuing' },
  { name: 'user',     detail: 'Profiles, preferences, public profile' },
  { name: 'auction',  detail: 'Listings, lifecycle, Buy It Now. Source of truth for price and end time', strong: true },
  { name: 'bidding',  detail: 'Bid placement and history', strong: true },
  { name: 'wallet',   detail: 'Balances, deposit locks, refunds, payment holds' },
  { name: 'media',    detail: 'Notifications, STOMP push, image uploads, audit log' },
]

const PLATFORM: readonly Chip[] = [
  { name: 'PostgreSQL 15',   detail: 'Liquibase migrations' },
  { name: 'Apache Kafka',    detail: 'event bus' },
  { name: 'Redis 7',         detail: 'bid context cache, alert batching' },
  { name: 'JobRunr',         detail: 'closure and ending-soon jobs' },
  { name: 'S3 + CloudFront', detail: 'images' },
]

interface BidStep {
  name: string
  body: ReactNode
  warn?: boolean
}

const Code = ({ children }: { children: ReactNode }) => <code className="font-mono text-[0.85em]">{children}</code>

const BID_STEPS: readonly BidStep[] = [
  { name: 'Gateway',   body: <><Code>POST /api/v1/bids</Code> arrives with a JWT. The gateway validates it and forwards <Code>X-User-Id</Code>.</> },
  { name: 'Pre-check', body: "Bidding reads the auction's context from Redis (or from auction on a miss) and rejects own-auction, closed and too-low bids early." },
  { name: 'Deposit',   body: 'On a first bid, wallet locks the deposit through an idempotent internal call.' },
  { name: 'Apply',     body: <>Bidding inserts the bid and asks auction to apply it. Auction takes <Code>SELECT … FOR UPDATE</Code> on the row and checks again.</> },
  { name: 'Extend',    body: <>In the same transaction, under 120 s left means end time +300 s and a row in <Code>auction_extensions</Code>.</>, warn: true },
  { name: 'Commit',    body: 'Bidding commits and answers 201 with the new price, bid count and end time.' },
  { name: 'Publish',   body: <>After commit: <Code>BidPlacedEvent</Code>, and <Code>AuctionExtendedEvent</Code> if extended. Publishing never blocks the bid.</> },
  { name: 'Push',      body: <>Media consumes the events and pushes them to <Code>/topic/auctions/{'{id}'}</Code>, plus an outbid alert to the previous leader.</> },
]

const TOPICS = [
  { topic: 'bid-placed-topic',          from: 'bidding',     use: 'Live price, outbid and new-bid alerts' },
  { topic: 'auction-extended-topic',    from: 'auction',     use: 'Live countdown, extension alert, cache eviction' },
  { topic: 'auction-ended-topic',       from: 'auction',     use: "Refund losers, open the winner's payment hold, won/lost/unsold alerts" },
  { topic: 'auction-cancelled-topic',   from: 'auction',     use: 'Refund every deposit, notify bidders and seller' },
  { topic: 'auction-ending-soon-topic', from: 'auction',     use: '60- and 15-minute alerts to bidders' },
  { topic: 'payment-event-topic',       from: 'wallet',      use: 'Payment required, reminder, completed, failed' },
  { topic: 'deposit-refunded-topic',    from: 'wallet',      use: 'Deposit refunded notice' },
  { topic: 'user-registered-topic',     from: 'identity',    use: 'Welcome notification and email' },
  { topic: 'audit-events',              from: 'any service', use: 'Before and after snapshots, stored by media' },
] as const

const CHANNELS = [
  { name: '/topic/auctions/{id}',      body: 'Public, guests included. BID_PLACED, AUCTION_EXTENDED, AUCTION_ENDED, AUCTION_CANCELLED.' },
  { name: '/user/queue/notifications', body: 'Private, signed-in only. Each new inbox notification plus the unread count.' },
] as const

const AWS_TIERS = [
  {
    title: 'Tier 1 · Presentation',
    items: [
      ['CloudFront', 'HTTPS, caches static files, serves uploads from a private S3 bucket'],
      ['Application Load Balancer', "refuses requests without CloudFront's secret origin header; /api and /ws-notifications go to the gateway, the rest to the frontend"],
    ],
  },
  {
    title: 'Tier 2 · Application',
    items: [
      ['ECS on Fargate', 'the frontend and seven Spring Boot services in private subnets'],
      ['ECS Service Connect', 'replaces Eureka for discovery'],
      ['Secrets Manager + IAM task roles', 'no stored access keys'],
    ],
  },
  {
    title: 'Tier 3 · Data',
    items: [
      ['RDS PostgreSQL 15', 'one database per service'],
      ['ElastiCache Redis 7', 'cache and alert batching'],
      ['Amazon MSK', '2 Kafka brokers, TLS'],
      ['Isolated subnets', 'no internet route'],
    ],
  },
] as const

const AWS_EXTRAS = [
  'GitHub Actions deploys through OIDC, pushing images to ECR',
  'A NAT gateway carries SMTP, ECR and CloudWatch traffic',
  'Locally: one Docker Compose file with Postgres, Redis, Kafka, Kafka UI and Mailpit',
] as const

const DIAGRAM_FRAME =
  'overflow-x-auto rounded-xl border border-[var(--color-border-default)] bg-[var(--color-bg-elevated)]'

function ChipItem({ name, detail, strong }: Chip) {
  return (
    <span
      className={cn(
        'rounded-lg px-4 py-3 text-sm',
        strong ? 'bg-brand-600 text-white' : 'border border-[var(--color-border-default)] bg-card',
      )}
    >
      <b className="font-semibold">{name}</b> · {detail}
    </span>
  )
}

function LayerArrow() {
  return <ArrowDown className="mx-auto size-5 text-muted-foreground" aria-hidden="true" />
}

export default function ArchitecturePage() {
  return (
    <>
      <PageHero
        eyebrow="Architecture"
        title="Eight Spring Boot modules, one request path."
        description="A Java 17, Spring Boot 3.2 and Spring Cloud multi-module build. Requests enter through one gateway, synchronous calls go over OpenFeign, and everything that can wait travels as a Kafka event."
      >
        <FactList facts={FACTS} />
      </PageHero>

      <Section id="system-map">
        <SectionHeading eyebrow="System map" title="Four layers, top to bottom." />
        <div className="grid gap-3">
          {LAYERS.map(({ label, chips }) => (
            <div key={label} className="contents">
              <Card className="flex flex-wrap items-center gap-4 p-5">
                <span className="w-36 shrink-0 font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">{label}</span>
                <div className="flex min-w-0 flex-1 flex-wrap gap-2.5">
                  {chips.map((chip) => <ChipItem key={chip.name} {...chip} />)}
                </div>
              </Card>
              <LayerArrow />
            </div>
          ))}
          <Card className="p-5">
            <span className="font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">
              Domain services · each with its own PostgreSQL database
            </span>
            <ul className="mt-4 grid gap-2.5 sm:grid-cols-2 lg:grid-cols-6">
              {DOMAIN_SERVICES.map(({ name, detail, strong }) => (
                <li
                  key={name}
                  className={cn(
                    'rounded-lg border bg-card p-4',
                    strong ? 'border-2 border-[var(--color-text-brand)]' : 'border-[var(--color-border-default)]',
                  )}
                >
                  <p className="font-semibold">{name}</p>
                  <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{detail}</p>
                </li>
              ))}
            </ul>
          </Card>
          <LayerArrow />
          <Card className="flex flex-wrap items-center gap-4 bg-[var(--color-bg-elevated)] p-5">
            <span className="w-36 shrink-0 font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">Platform</span>
            <div className="flex min-w-0 flex-1 flex-wrap gap-2.5">
              {PLATFORM.map((chip) => <ChipItem key={chip.name} {...chip} />)}
            </div>
          </Card>
        </div>
        <p className="mt-5 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          A shared <Code>common</Code> module supplies the response wrapper, error handling and identity-header filter.
          Internal endpoints under <Code>/internal</Code> are reachable only service to service; the gateway answers
          them with 403.
        </p>
      </Section>

      <Section id="life-of-a-bid" tinted>
        <SectionHeading eyebrow="Life of a bid" title={'What happens between "Place bid" and every screen updating.'} />
        <ol className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {BID_STEPS.map(({ name, body, warn }, i) => (
            <li key={name}>
              <Card className={cn('h-full p-5', warn && 'border-[var(--color-warning-default)]')}>
                <Kicker className={warn ? 'text-[var(--color-warning-text)]' : undefined}>{i + 1} · {name}</Kicker>
                <p className="mt-2 text-sm leading-relaxed">{body}</p>
              </Card>
            </li>
          ))}
        </ol>
        <MoreLink href={repoFileUrl('docs/diagrams/03-bidding-antisniping-flow.md')} className="mt-8">
          Full sequence diagram
        </MoreLink>
      </Section>

      <Section id="events">
        <div className="flex flex-wrap items-start gap-12">
          <div className="min-w-0 flex-[999_1_560px]">
            <SectionHeading eyebrow="Events" title="Who tells whom, over Kafka." />
            <div className="overflow-x-auto rounded-xl border border-[var(--color-border-default)]">
              <table className="w-full min-w-[560px] border-collapse text-sm">
                <thead>
                  <tr className="bg-[var(--color-bg-elevated)] text-left">
                    <th scope="col" className="px-4 py-3 font-semibold">Topic</th>
                    <th scope="col" className="px-4 py-3 font-semibold">From</th>
                    <th scope="col" className="px-4 py-3 font-semibold">Used for</th>
                  </tr>
                </thead>
                <tbody>
                  {TOPICS.map(({ topic, from, use }) => (
                    <tr key={topic} className="border-t border-[var(--color-border-default)]">
                      <td className="whitespace-nowrap px-4 py-3 font-mono text-[0.8rem]">{topic}</td>
                      <td className="px-4 py-3">{from}</td>
                      <td className="px-4 py-3 text-muted-foreground">{use}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <div className="min-w-0 flex-[1_1_340px]">
            <SectionHeading eyebrow="Real time" title="Two channels to the browser." />
            <div className="grid gap-3">
              {CHANNELS.map(({ name, body }) => (
                <Card key={name} className="p-5">
                  <p className="font-mono text-sm text-[var(--color-text-brand)]">{name}</p>
                  <p className="mt-2 text-sm leading-relaxed">{body}</p>
                </Card>
              ))}
              <p className="text-sm leading-relaxed text-muted-foreground">
                Clients are receive-only: the STOMP guard allows only CONNECT, SUBSCRIBE and their counterparts, and
                only to these two destinations.
              </p>
            </div>
          </div>
        </div>
      </Section>

      {/* AWS: follows the theme switch */}
      <Section id="aws" tinted>
        <SectionHeading
          eyebrow="Deployment on AWS"
          title="Three tiers behind a CDN, defined in Terraform."
          description="The demo stack runs in ap-southeast-2. CloudFront is the only public entry point; nothing behind it has a public address."
        />
        <figure className="m-0">
          <div className={cn(DIAGRAM_FRAME, 'bg-white')}>
            <Image
              src="/architecture/aws-deployment.svg"
              width={1728}
              height={1084}
              alt="BidNow on AWS. Users reach CloudFront, which serves uploaded media from a private S3 bucket and forwards everything else through an Internet gateway to an Application Load Balancer in the public subnets. The load balancer sends page requests to the frontend and API and WebSocket requests to the API gateway, which calls six services on ECS Fargate in private subnets. Those services use RDS PostgreSQL, ElastiCache Redis and Amazon MSK in isolated data subnets. Secrets Manager, ECR, IAM and a NAT gateway support the cluster."
              className="block h-auto w-full min-w-[1400px]"
              unoptimized
            />
          </div>
          <figcaption className="mt-3 text-sm text-muted-foreground">
            BidNow on AWS, three-tier architecture. Scroll sideways on small screens.
          </figcaption>
        </figure>
        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {AWS_TIERS.map(({ title, items }) => (
            <Card key={title}>
              <Kicker>{title}</Kicker>
              <ul className="mt-4 grid gap-2.5 text-sm leading-relaxed">
                {items.map(([name, detail]) => (
                  <li key={name}>
                    <b className="font-semibold">{name}</b> · {detail}
                  </li>
                ))}
              </ul>
            </Card>
          ))}
        </div>
        <ul className="mt-4 flex flex-wrap gap-2.5">
          {AWS_EXTRAS.map((text) => (
            <li key={text} className="rounded-lg border border-[var(--color-border-default)] px-3.5 py-2.5 text-sm text-muted-foreground">
              {text}
            </li>
          ))}
        </ul>
        <MoreLink href={repoFileUrl('docs/deployment-aws.md')} className="mt-8">Deployment runbook</MoreLink>
      </Section>

      <Section>
        <div className="flex flex-wrap items-center justify-between gap-6">
          <h2 className="min-w-0 flex-[1_1_480px] font-display text-[length:var(--font-size-2xl)] font-medium leading-snug">
            Why it is built this way, problem by problem.
          </h2>
          <LinkButton href="/engineering">Engineering deep dives</LinkButton>
        </div>
      </Section>
    </>
  )
}
