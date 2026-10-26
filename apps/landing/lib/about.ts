/** Static content for the About page (`/about`): project status, tech stack and the team. */

export interface StatusGroup {
  title: string
  items: readonly string[]
}

export const BUILT: StatusGroup = {
  title: 'Built',
  items: [
    'Registration with email OTP, login, profiles',
    'Listings with images, categories and Buy It Now',
    'Live bidding with anti-sniping extensions',
    'Wallet, deposit locks, refunds and the 48-hour payment window',
    'In-app and email notifications with an inbox',
    'Admin tools, audit log, distributed tracing',
    'AWS deployment in Terraform with a GitHub Actions pipeline',
  ],
}

export const NOT_BUILT: StatusGroup = {
  title: 'Not built yet',
  items: [
    'Auto-bidding with a maximum bid (phase 2)',
    'An external payment gateway, Stripe or VNPay',
    'Session affinity for the WebSocket fallback when media-service runs more than one instance',
  ],
}

export const OUT_OF_SCOPE = 'Out of scope for now: shipping, disputes, seller analytics and multiple currencies.'

export interface StackItem {
  name: string
  role: string
}

export interface StackGroup {
  title: string
  items: readonly StackItem[]
}

export const STACK: readonly StackGroup[] = [
  {
    title: 'Frontend',
    items: [
      { name: 'Next.js 16',            role: 'App Router, server rendering' },
      { name: 'React 19',              role: 'UI' },
      { name: 'TypeScript',            role: 'Typed API payloads' },
      { name: 'Tailwind CSS 4',        role: 'Styling, design tokens' },
      { name: 'shadcn/ui, Base UI',    role: 'Components' },
      { name: 'Zustand',               role: 'Client state' },
      { name: 'STOMP over WebSocket',  role: 'Live bids' },
      { name: 'Three.js, Motion',      role: 'Hero watch, animation' },
      { name: 'Vitest',                role: 'Unit tests' },
    ],
  },
  {
    title: 'Backend',
    items: [
      { name: 'Java 17',               role: 'Language' },
      { name: 'Spring Boot 3.2',       role: 'Service runtime' },
      { name: 'Spring Cloud Gateway',  role: 'Routing, JWT check' },
      { name: 'Eureka, OpenFeign',     role: 'Discovery, sync calls' },
      { name: 'Spring Security, JJWT', role: 'Auth' },
      { name: 'Liquibase',             role: 'Schema migrations' },
      { name: 'JobRunr',               role: 'Scheduled auction jobs' },
      { name: 'MapStruct, Lombok',     role: 'Mapping, boilerplate' },
      { name: 'springdoc OpenAPI',     role: 'Swagger at the gateway' },
    ],
  },
  {
    title: 'Data and messaging',
    items: [
      { name: 'PostgreSQL 15+',        role: 'One database per service' },
      { name: 'Apache Kafka',          role: 'Event bus' },
      { name: 'Redis 7',               role: 'Cache, alert batching' },
      { name: 'STOMP broker',          role: 'Kafka events to browsers' },
      { name: 'Amazon S3, CloudFront', role: 'Media uploads, CDN' },
    ],
  },
  {
    title: 'Quality and delivery',
    items: [
      { name: 'JUnit, Mockito',        role: 'Unit tests' },
      { name: 'Cucumber',              role: 'BDD scenarios' },
      { name: 'JaCoCo',                role: 'Coverage' },
      { name: 'GitHub Actions',        role: 'CI, security, deploys' },
      { name: 'Terraform',             role: 'AWS infrastructure' },
      { name: 'Docker, Maven',         role: 'Images, multi-module build' },
    ],
  },
]

export interface Developer {
  name:   string
  handle: string
}

export const DEVELOPERS: readonly Developer[] = [
  { name: 'Hiep Nguyen', handle: 'hiepnguyen06' },
  { name: 'Khoa Ly',     handle: 'KhoaLy2003' },
]

export function githubUrl(handle: string): string {
  return `https://github.com/${handle}`
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase())
    .slice(0, 2)
    .join('')
}
