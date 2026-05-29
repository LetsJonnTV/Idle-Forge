/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    instrumentationHook: true,
  },
  // Bundle schema.sql into the Vercel serverless deployment
  outputFileTracingIncludes: {
    '/api/**': ['./supabase/schema.sql'],
  },
};

module.exports = nextConfig;
