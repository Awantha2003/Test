import { runScan } from '@/lib/scan';

export const dynamic = 'force-dynamic';
export const maxDuration = 120;

function authorized(req) {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  const url = new URL(req.url);
  const auth = req.headers.get('authorization') || '';
  return url.searchParams.get('key') === secret || auth === `Bearer ${secret}`;
}

export async function GET(req) {
  if (!authorized(req)) return Response.json({ error: 'unauthorized' }, { status: 401 });
  try {
    const result = await runScan();
    return Response.json(result);
  } catch (e) {
    return Response.json({ error: String(e.message || e) }, { status: 500 });
  }
}

export const POST = GET;
