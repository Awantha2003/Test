import { authToken } from './lib/auth.js';
import { NextResponse } from 'next/server';

export async function middleware(req) {
  const { pathname } = req.nextUrl;
  if (pathname.startsWith('/login') || pathname.startsWith('/api/cron') || pathname.startsWith('/_next') || pathname === '/favicon.ico') {
    return NextResponse.next();
  }
  const pw = process.env.APP_PASSWORD;
  if (!pw) return NextResponse.next();
  const cookie = req.cookies.get('lj_auth')?.value;
  if (cookie && cookie === (await authToken(pw))) return NextResponse.next();
  const url = req.nextUrl.clone();
  url.pathname = '/login';
  url.search = '';
  return NextResponse.redirect(url);
}

export const config = { matcher: ['/((?!_next/static|_next/image).*)'] };
