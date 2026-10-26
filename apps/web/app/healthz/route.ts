// ALB target-group health check: answers without touching the gateway, so a cold backend cannot fail it.
export const dynamic = 'force-dynamic'

export function GET(): Response {
  return new Response('ok', { status: 200, headers: { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' } })
}
