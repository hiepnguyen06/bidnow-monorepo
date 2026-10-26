import { Arrow, ArrowMarkers, Label, Node } from './diagram-parts'

const P = 'aws'

const SUPPORT = [
  { x: 48,  name: 'ECR',             what: 'images' },
  { x: 260, name: 'Secrets Manager', what: 'secrets' },
  { x: 472, name: 'CloudWatch',      what: 'logs' },
  { x: 684, name: 'IAM',             what: 'roles' },
] as const

const SERVICES = [
  'identity-service',
  'user-service',
  'auction-service',
  'bidding-service',
  'wallet-service',
  'media-service',
] as const

const MUTED ='var(--color-text-secondary)'

/**
 * The deployed AWS stack, kept to the core: CloudFront and S3 at the edge, one ALB, one ECS Fargate cluster
 * (the Next.js frontend and the Spring Boot services), then the managed data stores. Meant to sit on a `dark` surface.
 */
export function AwsArchitectureDiagram() {
  return (
    <svg
      viewBox="0 0 1200 656"
      role="img"
      aria-labelledby="aws-title aws-desc"
      className="block h-auto w-full min-w-[1000px] font-sans"
    >
      <title id="aws-title">BidNow on AWS: three-tier architecture</title>
      <desc id="aws-desc">
        Users reach Amazon CloudFront, which serves uploaded media from a private S3 bucket and forwards everything
        else to an Application Load Balancer in the VPC. The load balancer sends page requests to the Next.js frontend
        service and API and WebSocket requests to the backend services, which are the API gateway and six domain
        services. All of them run as containers on Amazon ECS with Fargate in private subnets. The backend services use
        RDS for PostgreSQL, ElastiCache for Redis and Amazon MSK in the data tier.
      </desc>
      <ArrowMarkers prefix={P} />

      {/* zones */}
      <rect x={392} y={48} width={760} height={476} rx={12} fill="none" strokeWidth={1} strokeDasharray="5 4" style={{ stroke: 'var(--color-border-strong)' }} />
      <Node x={408} y={88} w={184} h={420} variant="band" />
      <Node x={640} y={88} w={240} h={420} variant="band" />
      <Node x={928} y={88} w={208} h={420} variant="band" />
      <Node x={656} y={132} w={208} h={348} variant="zone" />

      {/* traffic */}
      <Arrow prefix={P} tone="traffic" d="M160 292 H208" />
      <Arrow prefix={P} tone="traffic" d="M360 292 H424" />
      <Arrow prefix={P} tone="traffic" d="M284 340 V404" />
      <Arrow prefix={P} tone="traffic" d="M576 280 H606 V180 H672" />
      <Arrow prefix={P} tone="traffic" d="M576 304 H626 V220 H672" />
      <Arrow prefix={P} tone="traffic" d="M760 236 V252" />

      {/* data access: the domain services fan out to the three stores */}
      <Arrow prefix={P} tone="data" head={false} d="M862 360 H896" />
      <Arrow prefix={P} tone="data" head={false} d="M896 192 V448" />
      <Arrow prefix={P} tone="data" d="M896 192 H944" />
      <Arrow prefix={P} tone="data" d="M896 320 H944" />
      <Arrow prefix={P} tone="data" d="M896 448 H944" />

      {/* zone titles */}
      <Label x={408} y={68} text="VPC · ALB in public subnets, services and data in private subnets" size={12} mono fill={MUTED} />
      <Label x={420} y={112} text="TIER 1 · PRESENTATION" size={11} mono fill={MUTED} />
      <Label x={652} y={112} text="TIER 2 · APPLICATION" size={11} mono fill={MUTED} />
      <Label x={940} y={112} text="TIER 3 · DATA" size={11} mono fill={MUTED} />
      <Label x={668} y={152} text="ECS on Fargate" size={12} fill="var(--color-text-brand)" />

      {/* edge */}
      <Node x={48}  y={244} w={112} h={96} title="Users" lines={['Web browser']} />
      <Node x={208} y={244} w={152} h={96} variant="accent" title="Amazon CloudFront" lines={['CDN · HTTPS']} />
      <Node x={208} y={404} w={152} h={96} title="Amazon S3" lines={['Media uploads']} />

      {/* tier 1 */}
      <Node x={424} y={244} w={152} h={96} variant="accent" title={['Application', 'Load Balancer']} lines={['/ to frontend', '/api, /ws to gateway']} />

      {/* tier 2 */}
      <Node x={672} y={164} w={176} h={32} titleSize={13} title="frontend" />
      <Node x={672} y={204} w={176} h={32} titleSize={13} variant="accent" title="api-gateway" />
      <Node x={666} y={252} w={196} h={216} variant="band" />
      {SERVICES.map((name, i) => (
        <Node key={name} x={672} y={261 + i * 34} w={176} h={28} titleSize={13} title={name} />
      ))}

      {/* tier 3 */}
      <Node x={944} y={148} w={176} h={88} variant="data" title="RDS for PostgreSQL" lines={['One database', 'per service']} />
      <Node x={944} y={276} w={176} h={88} variant="data" title="ElastiCache for Redis" lines={['Bid context cache,', 'alert batching']} />
      <Node x={944} y={404} w={176} h={88} variant="data" title="Amazon MSK" lines={['Managed Kafka event bus']} />

      {/* supporting services */}
      <Label x={48} y={560} text="SUPPORTING SERVICES" size={12} mono fill={MUTED} />
      {SUPPORT.map((s) => (
        <Node key={s.name} x={s.x} y={572} w={188} h={44} variant="chip" lines={[`${s.name} · ${s.what}`]} />
      ))}

      {/* captions */}
      <Label x={184} y={280} anchor="middle" text="HTTPS" />
      <Label x={296} y={378} text="origin" />
    </svg>
  )
}
