import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Framework-free workspace package compiled by Next (plain TS, no build step needed here).
  transpilePackages: ['@bookclass/shared'],
  // Self-contained server bundle for the production Docker image (ENG-00 §7).
  output: 'standalone',
};

export default nextConfig;
