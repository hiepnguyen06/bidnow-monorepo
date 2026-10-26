import type { ReactNode } from 'react'
import type { Metadata } from 'next'
import { Card, Kicker } from '@/components/Card'
import { MoreLink } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { Section, SectionHeading } from '@/components/home/Section'
import { REPO_URL, repoFileUrl } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Engineering',
  description:
    'Eight engineering notes on BidNow: concurrent bids, moving end times, real-time fan-out, notifications, money, gateway security, tracing and CI.',
}

const Code = ({ children }: { children: ReactNode }) => <code className="font-mono text-[0.85em]">{children}</code>

interface Note {
  tag:     string
  title:   string
  problem: string
  points:  readonly ReactNode[]
  link:    { href: string; label: string }
}

const NOTES: readonly Note[] = [
  {
    tag: 'Concurrency',
    title: 'Two bids, one price',
    problem: 'Two bidders, or a bid and the closing job, hit the same auction at the same instant. Only one can lead.',
    points: [
      'Redis holds a cached bid context, used only to reject obviously bad bids fast.',
      <>The decision is made in auction-service under <Code>SELECT … FOR UPDATE</Code>, serialized with closure and cancellation.</>,
      <>Applying a bid is idempotent on its <Code>bidId</Code>, and <Code>last_bid_id</Code> is kept for reconciliation.</>,
    ],
    link: { href: repoFileUrl('docs/diagrams/03-bidding-antisniping-flow.md'), label: 'Bidding flow' },
  },
  {
    tag: 'Scheduling',
    title: 'Closing a clock that keeps moving',
    problem: 'Anti-sniping can push the end time back after the closing job is already scheduled.',
    points: [
      'JobRunr closure jobs are keyed on (auction, end time).',
      'They fire 20 s after the end time, because JobRunr can enqueue a job up to one poll interval early.',
      'A job that finds the auction extended reschedules itself. Ending-soon jobs do the same.',
    ],
    link: { href: repoFileUrl('docs/architecture.md'), label: 'Architecture notes' },
  },
  {
    tag: 'Real time',
    title: 'Every instance, every socket',
    problem: "With several media-service instances, the browser's socket may sit on any one of them.",
    points: [
      'Each instance consumes auction events with its own consumer group, so each pushes to its own clients.',
      <>User notifications fan out through <Code>user-notification-push-topic</Code> to whichever instance holds the socket.</>,
      'Delivery is best effort; the page re-fetches the auction on every reconnect.',
    ],
    link: { href: repoFileUrl('docs/diagrams/07-notification-delivery-flow.md'), label: 'Notification delivery' },
  },
  {
    tag: 'Notifications',
    title: 'Alerts that never double up',
    problem: 'Kafka can redeliver, and a bidding war can produce dozens of outbid alerts.',
    points: [
      'One stored notification per user and dedup key, so a redelivery does nothing.',
      'Outbid and new-bid alerts are batched in Redis over a 5-minute window.',
      'Media keeps its own projection of auctions and bidders, so it never calls another service to find recipients.',
    ],
    link: { href: repoFileUrl('docs/database/notification-service.schema.md'), label: 'Notification schema' },
  },
  {
    tag: 'Money',
    title: 'Money moves exactly once',
    problem: 'Deposits, refunds and payments cross service boundaries and retries.',
    points: [
      'Deposit locks are idempotent; each refund is its own transaction and skips locks already released.',
      'Paying locks the payment hold first, then both wallets in ascending id order.',
      'Failed wallet events retry three times (1 s, 2 s, 4 s), then go to a dead-letter topic.',
    ],
    link: { href: repoFileUrl('docs/diagrams/05-winner-payment-flow.md'), label: 'Payment flow' },
  },
  {
    tag: 'Security',
    title: 'One door in',
    problem: 'Services trust identity headers, so nobody outside may forge them.',
    points: [
      <>Only the gateway reads the JWT; it strips client-sent <Code>X-User-Id</Code> and <Code>X-User-Roles</Code>.</>,
      <>Routes are explicit; <Code>/internal</Code> paths are refused, and a test enforces it.</>,
      'On the WebSocket path, path tricks get a 400 and the access token is never forwarded.',
    ],
    link: { href: repoFileUrl('docs/diagrams/01-user-auth-flow.md'), label: 'Auth flow' },
  },
  {
    tag: 'Observability',
    title: 'One trace ID, every hop',
    problem: 'A single bid touches several services and topics.',
    points: [
      'Micrometer Tracing puts a traceId in every log line, carried across Feign and Kafka.',
      'Logs are structured JSON, ready for any aggregator.',
      <>An <Code>@Audit</Code> aspect records before and after snapshots of significant actions.</>,
    ],
    link: { href: repoFileUrl('docs/distributed-tracing.md'), label: 'Tracing guide' },
  },
  {
    tag: 'Delivery',
    title: 'Checks on every change',
    problem: 'Eight modules and two front ends, kept working by two people.',
    points: [
      'GitHub Actions run backend, frontend and landing CI, security scans, image builds and Terraform validation.',
      'JUnit and Mockito, Cucumber scenarios, JaCoCo coverage, Vitest on the frontend.',
      'A push to main builds the images and, when the demo stack is up, rolls the ECS services.',
    ],
    link: { href: `${REPO_URL}/tree/main/.github/workflows`, label: 'Workflows' },
  },
]

const TARGETS = [
  { value: '200 ms', label: 'Bid broadcast to watchers' },
  { value: '1,000',  label: 'Concurrent users per auction' },
  { value: '300 ms', label: 'Average API response' },
  { value: '80%',    label: 'Unit coverage on bidding and wallet logic' },
] as const

export default function EngineeringPage() {
  return (
    <>
      <PageHero
        eyebrow="Engineering"
        title="The hard parts of a live auction, and how we handled them."
        description="Each note states the problem, the approach in the code, and links to the design document in the repository."
      />

      <Section id="notes">
        <div className="grid gap-5 md:grid-cols-2">
          {NOTES.map(({ tag, title, problem, points, link }, i) => (
            <Card key={title} className="flex flex-col p-8">
              <Kicker className="text-[var(--color-warning-text)]">0{i + 1} · {tag}</Kicker>
              <h2 className="mt-3.5 font-display text-[length:var(--font-size-xl)] font-medium leading-tight">{title}</h2>
              <p className="mt-3 leading-relaxed text-muted-foreground">
                <b className="font-semibold text-foreground">Problem.</b> {problem}
              </p>
              <ul className="mt-4 grid list-disc gap-2 pl-5 text-sm leading-relaxed">
                {points.map((point, j) => <li key={j}>{point}</li>)}
              </ul>
              <MoreLink href={link.href} className="mt-auto pt-5">{link.label}</MoreLink>
            </Card>
          ))}
        </div>
      </Section>

      <Section id="targets" tinted>
        <SectionHeading
          eyebrow="Design targets"
          title="The numbers the design aims for."
          description="From the non-functional requirements. These are goals, not measured results."
        />
        <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {TARGETS.map(({ value, label }) => (
            <Card key={label} className="flex flex-col">
              <dt className="order-2 mt-1.5 text-sm text-muted-foreground">{label}</dt>
              <dd className="order-1 font-mono text-3xl">{value}</dd>
            </Card>
          ))}
        </dl>
        <MoreLink href={repoFileUrl('docs/non-functional.md')} className="mt-8">Non-functional requirements</MoreLink>
      </Section>
    </>
  )
}
