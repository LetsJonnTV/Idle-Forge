/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    instrumentationHook: true,
  },
  // Bundle schema.sql so runtime migrations can read it in container deployments
  outputFileTracingIncludes: {
    '/api/**': ['./supabase/schema.sql'],
  },
};

module.exports = nextConfig;
