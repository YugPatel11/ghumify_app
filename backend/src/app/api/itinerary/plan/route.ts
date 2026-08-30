import { NextResponse } from 'next/server';

interface Location {
  id: string;
  lat: number;
  lng: number;
  name: string;
}

export async function POST(request: Request) {
  try {
    const { origin, destinations, mode = 'driving' } = await request.json();

    if (!origin || !destinations || destinations.length === 0) {
      return NextResponse.json(
        { error: 'Origin and at least one destination are required.' },
        { status: 400 }
      );
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return NextResponse.json(
        { error: 'Google Maps API key is not configured.' },
        { status: 500 }
      );
    }

    // Prepare all points: origin + destinations
    const allPoints: Location[] = [origin, ...destinations];
    
    // To calculate the best order, we'll fetch the full distance matrix between all points
    const formatLocations = (locations: Location[]) =>
      locations.map((loc) => `${loc.lat},${loc.lng}`).join('|');
    const pointStr = formatLocations(allPoints);

    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${pointStr}&destinations=${pointStr}&mode=${mode}&key=${apiKey}`;

    const response = await fetch(url);
    const data = await response.json();

    if (data.status !== 'OK') {
      return NextResponse.json(
        { error: `Google Maps API Error: ${data.status}`, details: data },
        { status: 400 }
      );
    }

    // Implement a simple Nearest Neighbor algorithm to suggest a route
    // Start at origin (index 0)
    const unvisited = new Set(destinations.map((d: Location) => d.id));
    const orderedDestinations: Location[] = [];
    const routeSegments = [];
    let totalDistanceValue = 0;
    let totalDurationValue = 0;

    let currentIndex = 0; // Starts at origin

    while (unvisited.size > 0) {
      let nearestIndex = -1;
      let minDistance = Infinity;
      let segmentDetails = null;
      let nearestDestinationId = null;

      // Find the nearest unvisited neighbor
      for (let j = 1; j < allPoints.length; j++) {
        const destId = allPoints[j].id;
        if (unvisited.has(destId)) {
          const element = data.rows[currentIndex].elements[j];
          if (element.status === 'OK' && element.distance.value < minDistance) {
            minDistance = element.distance.value;
            nearestIndex = j;
            nearestDestinationId = destId;
            segmentDetails = element;
          }
        }
      }

      if (nearestIndex === -1) {
        // Fallback if unreachable
        break;
      }

      // Add to route
      const nextDest = allPoints[nearestIndex];
      orderedDestinations.push(nextDest);
      unvisited.delete(nearestDestinationId!);

      routeSegments.push({
        from: allPoints[currentIndex].name,
        to: nextDest.name,
        distance: segmentDetails.distance.text,
        distanceValue: segmentDetails.distance.value,
        duration: segmentDetails.duration.text,
        durationValue: segmentDetails.duration.value,
      });

      totalDistanceValue += segmentDetails.distance.value;
      totalDurationValue += segmentDetails.duration.value;
      
      currentIndex = nearestIndex;
    }

    // Convert values to readable formats (approx)
    const totalDistanceKm = (totalDistanceValue / 1000).toFixed(1) + ' km';
    const totalDurationMins = Math.round(totalDurationValue / 60);
    const totalDurationText = totalDurationMins > 60 
      ? `${Math.floor(totalDurationMins / 60)} hr ${totalDurationMins % 60} min`
      : `${totalDurationMins} min`;

    return NextResponse.json({
      title: 'Suggested Visit Order',
      message: 'This route reduces unnecessary backtracking based on travel distance.',
      orderedDestinations,
      routeSegments,
      totalDistance: totalDistanceKm,
      totalDuration: totalDurationText,
      totalDistanceValue,
      totalDurationValue,
    });
  } catch (error: any) {
    console.error('Itinerary planning error:', error);
    return NextResponse.json(
      { error: 'Failed to plan itinerary.', details: error.message },
      { status: 500 }
    );
  }
}
