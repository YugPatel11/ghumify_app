import { NextRequest } from 'next/server';
import { POST } from '../app/api/crowd/recommend/route';

async function verifyEndpoint() {
  console.log('=== Verifying /api/crowd/recommend Route Handler ===\n');

  // 1. Test Flag OFF -> 404
  delete process.env.CROWD_AWARE_ENABLED;
  const reqFlagOff = new NextRequest('http://localhost:3000/api/crowd/recommend', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ city: 'Jaipur', date: '2026-11-02' }),
  });
  const resFlagOff = await POST(reqFlagOff);
  const dataFlagOff = await resFlagOff.json();
  console.log(`1. Flag OFF Check: Status ${resFlagOff.status}`);
  console.log('   Response:', JSON.stringify(dataFlagOff));
  if (resFlagOff.status !== 404) throw new Error('Expected 404 when flag is off');

  // Turn flag ON for remaining tests
  process.env.CROWD_AWARE_ENABLED = 'true';

  // 2. Test Missing Token -> 401
  const reqNoAuth = new NextRequest('http://localhost:3000/api/crowd/recommend', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ city: 'Jaipur', date: '2026-11-02' }),
  });
  const resNoAuth = await POST(reqNoAuth);
  const dataNoAuth = await resNoAuth.json();
  console.log(`\n2. Missing Token Check: Status ${resNoAuth.status}`);
  console.log('   Response:', JSON.stringify(dataNoAuth));
  if (resNoAuth.status !== 401) throw new Error('Expected 401 when token is missing');

  // 3. Test Bad Input -> 400
  const reqBadInput = new NextRequest('http://localhost:3000/api/crowd/recommend', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer test_token_user_demo',
    },
    body: JSON.stringify({
      city: '', // Empty city triggers validation error
      date: 'invalid-date', // Bad regex format
    }),
  });
  const resBadInput = await POST(reqBadInput);
  const dataBadInput = await resBadInput.json();
  console.log(`\n3. Bad Input Check: Status ${resBadInput.status}`);
  console.log('   Response:', JSON.stringify(dataBadInput));
  if (resBadInput.status !== 400) throw new Error('Expected 400 for bad input');

  // 4. Test Success -> 200
  const reqSuccess = new NextRequest('http://localhost:3000/api/crowd/recommend', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer test_token_user_demo',
    },
    body: JSON.stringify({
      city: 'Jaipur',
      date: '2026-11-02',
      startTime: '09:00',
      endTime: '18:00',
      avoidCrowds: true,
      budgetCap: 1000,
      candidates: [
        {
          id: 'curated_amber_palace',
          name: 'Amber Palace',
          category: 'fort',
          latitude: 26.9855,
          longitude: 75.8513,
          entryFee: 500,
          openingHours: { daily: '09:00-17:30' },
          durationMinutes: 90,
        },
        {
          id: 'jaigarh_fort',
          name: 'Jaigarh Fort',
          category: 'fort',
          latitude: 26.9850,
          longitude: 75.8450,
          entryFee: 200,
          openingHours: { daily: '09:00-18:30' },
          popularity: 30, // lower crowd alternative
          durationMinutes: 90,
        },
        {
          id: 'curated_hawa_mahal',
          name: 'Hawa Mahal',
          category: 'heritage',
          latitude: 26.9239,
          longitude: 75.8267,
          entryFee: 200,
          openingHours: { daily: '09:00-17:00' },
          durationMinutes: 60,
        },
      ],
    }),
  });
  const resSuccess = await POST(reqSuccess);
  const dataSuccess = await resSuccess.json();
  console.log(`\n4. Success Check: Status ${resSuccess.status}`);
  console.log('   Stops returned:', dataSuccess.stops?.length);
  console.log('   First stop:', dataSuccess.stops?.[0]?.name, `(${dataSuccess.stops?.[0]?.suggestedStart} - ${dataSuccess.stops?.[0]?.suggestedEnd})`);
  console.log('   Alternatives for first stop:', JSON.stringify(dataSuccess.stops?.[0]?.alternatives));
  if (resSuccess.status !== 200) throw new Error('Expected 200 for valid recommendation request');

  console.log('\n=== All 4 Endpoint Checks Passed Successfully! ===');
}

verifyEndpoint().catch((err) => {
  console.error('Endpoint verification failed:', err);
  process.exit(1);
});
