import type { NextConfig } from "next";
import { LANDING_URL } from "./lib/navigation";

const nextConfig: NextConfig = {
  output: 'standalone',
  async redirects() {
    return [{ source: '/about', destination: LANDING_URL, permanent: false }];
  },
  images: {
    dangerouslyAllowLocalIP: true,
    qualities: [75, 90],
    remotePatterns: [
      {
        protocol: 'http',
        hostname: 'localhost',
        port: '8080',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
  },
};

export default nextConfig;
