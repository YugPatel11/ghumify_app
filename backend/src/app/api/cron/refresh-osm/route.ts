import { NextRequest, NextResponse } from 'next/server';
import { cacheStore, setPlacesInCache } from '@/lib/cache';
import { OsmPlaceProvider } from '@/lib/places/osm-provider';

export async function GET(request: NextRequest) {
  // Validate cron secret if set in production
  const authHeader = request.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const requestedCities = await cacheStore.getRequestedCities(20);
  if (requestedCities.length === 0) {
    return NextResponse.json({ message: 'No user-requested cities to refresh.' });
  }

  const osm = new OsmPlaceProvider();
  const results: Array<{ city: string; placesCount: number; status: string }> = [];

  for (const city of requestedCities) {
    try {
      const places = await osm.search({ city, limit: 30 });
      if (places && places.length > 0) {
        const cacheKey = `search_${city.trim().toLowerCase()}`;
        await setPlacesInCache(cacheKey, places, 86400 * 7);
        results.push({ city, placesCount: places.length, status: 'refreshed' });
      } else {
        results.push({ city, placesCount: 0, status: 'empty' });
      }
    } catch (err: any) {
      results.push({ city, placesCount: 0, status: `error: ${err?.message || err}` });
    }
  }

  return NextResponse.json({
    success: true,
    refreshedAt: new Date().toISOString(),
    results,
  });
}

