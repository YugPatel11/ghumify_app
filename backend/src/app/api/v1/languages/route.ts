import { NextResponse } from 'next/server';
import { SUPPORTED_LANGUAGES } from '@/lib/languages';

export async function GET() {
  return NextResponse.json(
    {
      success: true,
      data: SUPPORTED_LANGUAGES.filter((l) => l.enabled),
    },
    {
      headers: {
        'Cache-Control': 'public, max-age=86400, s-maxage=86400',
      },
    }
  );
}
