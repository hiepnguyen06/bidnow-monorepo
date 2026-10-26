import { describe, expect, it } from 'vitest'
import { resolveWsEndpoint } from './ws-url'

describe('resolveWsEndpoint', () => {
  it('ws-url falls back to origin when apiUrl is empty', () => {
    expect(resolveWsEndpoint({ apiUrl: '', origin: 'https://d1.cloudfront.net' })).toBe(
      'wss://d1.cloudfront.net/ws-notifications/websocket',
    )
  })

  it('ws-url keeps explicit wsUrl', () => {
    expect(
      resolveWsEndpoint({ wsUrl: 'ws://example.test/custom', apiUrl: '', origin: 'https://d1.cloudfront.net' }),
    ).toBe('ws://example.test/custom')
  })

  it('ws-url maps http origin to ws', () => {
    expect(resolveWsEndpoint({ apiUrl: '', origin: 'http://localhost:3000' })).toBe(
      'ws://localhost:3000/ws-notifications/websocket',
    )
  })

  it('derives from apiUrl when set and keeps the localhost default when unset', () => {
    expect(resolveWsEndpoint({ apiUrl: 'https://api.example.com/' })).toBe(
      'wss://api.example.com/ws-notifications/websocket',
    )
    expect(resolveWsEndpoint({})).toBe('ws://localhost:8080/ws-notifications/websocket')
  })
})
