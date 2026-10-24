const LOCAL_GATEWAY_URL = 'http://localhost:8080'

/**
 * Base URL for REST calls to the gateway.
 *
 * Browser: `NEXT_PUBLIC_API_URL`, where "" means same origin (the CloudFront deployment).
 * Server (Server Components, route handlers): Node's fetch cannot resolve a relative URL, so an
 * empty public URL is skipped in favour of `API_INTERNAL_URL` (the in-cluster gateway address).
 *
 * `process.env.NEXT_PUBLIC_API_URL` must stay written literally so Next inlines it at build time.
 */
export function apiBaseUrl(): string {
  if (typeof window === 'undefined') {
    return process.env.API_INTERNAL_URL || process.env.NEXT_PUBLIC_API_URL || LOCAL_GATEWAY_URL
  }
  return process.env.NEXT_PUBLIC_API_URL ?? LOCAL_GATEWAY_URL
}
