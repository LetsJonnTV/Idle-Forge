/** @type {import('next').NextConfig} */
const nextConfig = {
  // API routes only — no pages needed for this backend
  experimental: {
    instrumentationHook: true,
  },
};

module.exports = nextConfig;
