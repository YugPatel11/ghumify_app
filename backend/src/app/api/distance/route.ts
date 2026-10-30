import { NextResponse } from 'next/server';
import { resolveLanguage } from '@/lib/language-resolution';

export async function POST(request: Request) {
  try {
    const requestUrl = new URL(request.url);
    const lang = resolveLanguage({
      headerLang: request.headers.get('x-language'),
      acceptLanguageHeader: request.headers.get('accept-language'),
      queryLang: requestUrl.searchParams.get('lang'),
    });

    const { origins, destinations, mode = 'driving' } = await request.json();

    if (!origins || !destinations) {
      return NextResponse.json(
        { code: 'ORIGINS_AND_DESTINATIONS_REQUIRED', error: 'Origins and destinations are required.', lang },
        { status: 400 }
      );
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return NextResponse.json(
        { code: 'MAPS_API_KEY_MISSING', error: 'Google Maps API key is not configured.', lang },
        { status: 500 }
      );
    }

    // Convert arrays of coordinates into string format for Google Maps API
    // e.g. "lat,lng|lat,lng"
    const formatLocations = (locations: { lat: number; lng: number }[]) =>
      locations.map((loc) => `${loc.lat},${loc.lng}`).join('|');

    const originStr = formatLocations(origins);
    const destinationStr = formatLocations(destinations);

    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originStr}&destinations=${destinationStr}&mode=${mode}&key=${apiKey}`;

    const response = await fetch(url);
    const data = await response.json();

    if (data.status !== 'OK') {
      return NextResponse.json(
        { error: `Google Maps API Error: ${data.status}`, details: data },
        { status: 400 }
      );
    }

    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Distance calculation error:', error);
    return NextResponse.json(
      { error: 'Failed to calculate distance.', details: error.message },
      { status: 500 }
    );
  }
}
