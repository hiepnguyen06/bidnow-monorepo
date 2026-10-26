import { afterEach, describe, expect, it, vi } from 'vitest'
import { apiBaseUrl } from './api-base'

afterEach(() => {
  vi.unstubAllEnvs()
  vi.unstubAllGlobals()
})

describe('apiBaseUrl on the server', () => {
  it('prefers API_INTERNAL_URL so server components reach the gateway directly', () => {
    vi.stubEnv('API_INTERNAL_URL', 'http://api-gateway:8080')
    vi.stubEnv('NEXT_PUBLIC_API_URL', '')

    expect(apiBaseUrl()).toBe('http://api-gateway:8080')
  })

  it('falls back to localhost when the public url is the same-origin empty string', () => {
    vi.stubEnv('API_INTERNAL_URL', '')
    vi.stubEnv('NEXT_PUBLIC_API_URL', '')

    expect(apiBaseUrl()).toBe('http://localhost:8080')
  })

  it('uses NEXT_PUBLIC_API_URL when no internal url is set', () => {
    vi.stubEnv('API_INTERNAL_URL', '')
    vi.stubEnv('NEXT_PUBLIC_API_URL', 'http://gateway.local:8080')

    expect(apiBaseUrl()).toBe('http://gateway.local:8080')
  })
})

describe('apiBaseUrl in the browser', () => {
  it('keeps the empty string so requests stay same-origin', () => {
    vi.stubGlobal('window', {})
    vi.stubEnv('API_INTERNAL_URL', 'http://api-gateway:8080')
    vi.stubEnv('NEXT_PUBLIC_API_URL', '')

    expect(apiBaseUrl()).toBe('')
  })

  it('defaults to localhost when NEXT_PUBLIC_API_URL is unset', () => {
    vi.stubGlobal('window', {})
    vi.stubEnv('NEXT_PUBLIC_API_URL', undefined)

    expect(apiBaseUrl()).toBe('http://localhost:8080')
  })
})
