import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_ORIGINS = [
  'https://idle-forge.jonn2008.me',
  'https://wiki.idle-forge.jonn2008.me',
  'http://localhost:4200',
  'http://localhost:3001', // local wiki dev
];

export function middleware(request: NextRequest) {
  const origin = request.headers.get('origin') ?? '';
  const isAllowed = ALLOWED_ORIGINS.includes(origin);

  const corsHeaders = {
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };

  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    if (!isAllowed) {
      return new NextResponse(null, {
        status: 403,
        headers: corsHeaders,
      });
    }

    return new NextResponse(null, {
      status: 204,
      headers: {
        ...corsHeaders,
        'Access-Control-Allow-Origin': origin,
      },
    });
  }

  const response = NextResponse.next();
  response.headers.set('Vary', 'Origin');

  if (isAllowed) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Methods', corsHeaders['Access-Control-Allow-Methods']);
    response.headers.set('Access-Control-Allow-Headers', corsHeaders['Access-Control-Allow-Headers']);
  }

  return response;
}

export const config = {
  matcher: '/api/:path*',
};
