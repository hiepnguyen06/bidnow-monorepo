import type { NextConfig } from 'next'

// Set by the GitHub Pages workflow (e.g. "/bidnow-monorepo") since project
// pages are served from a sub-path. Empty for local dev and builds.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? ''

const nextConfig: NextConfig = {
  output: 'export',
  images: { unoptimized: true },
  basePath,
  assetPrefix: basePath || undefined,
  trailingSlash: true,
}

export default nextConfig
