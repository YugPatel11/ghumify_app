import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { CURATED_CROWD_PROFILES, DEFAULT_HOLIDAYS, CrowdProfileRecord } from '../lib/crowd/profile-store';
import { CROWD_CONFIG } from '../lib/crowd/config';

async function seedCrowdData() {
  console.log('=== Seeding Ghumify Crowd Profiles & Holidays ===');

  let db: any = null;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    if (getApps().length === 0) {
      initializeApp({
        credential: cert({ projectId, clientEmail, privateKey }),
      });
    }
    db = getFirestore();
    console.log(`Connected to Firebase Firestore for project: ${projectId}`);
  } else {
    console.log('Firebase credentials not set in environment. Running in offline dry-run mode.');
  }

  // 1. Seed Curated City Profiles (Jaipur, Delhi, Agra) + Category Defaults
  console.log(`\nSeeding ${CURATED_CROWD_PROFILES.length} curated profiles...`);
  for (const profile of CURATED_CROWD_PROFILES) {
    const docData: CrowdProfileRecord = {
      ...profile,
      confidence: 'low', // Marked low as required unless statistics-backed
      updatedAt: new Date().toISOString(),
    };

    if (db) {
      await db.collection('crowdProfiles').doc(profile.placeId).set(docData, { merge: true });
      if (profile.googlePlaceId) {
        // Also map googlePlaceId if distinct
        await db.collection('crowdProfiles').doc(profile.googlePlaceId).set(docData, { merge: true });
      }
      console.log(`  [FIRESTORE] Seeded profile: ${profile.name} (${profile.city})`);
    } else {
      console.log(`  [DRY-RUN] Profile: ${profile.name} [${profile.placeId}] (City: ${profile.city}, Category: ${profile.category}, Confidence: ${profile.confidence})`);
    }
  }

  // 2. Seed Category Default Profiles
  console.log('\nSeeding category default profiles...');
  for (const [category, hourlyProfile] of Object.entries(CROWD_CONFIG.categoryHourlyProfiles)) {
    const categoryDoc: CrowdProfileRecord = {
      placeId: `category_default_${category}`,
      category,
      capacity: 'medium',
      hourlyProfile,
      weekendMultiplier: 1.30,
      seasonality: [1.2, 1.2, 1.0, 0.8, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.3],
      confidence: 'low',
      updatedAt: new Date().toISOString(),
    };

    if (db) {
      await db.collection('crowdProfiles').doc(categoryDoc.placeId).set(categoryDoc, { merge: true });
      console.log(`  [FIRESTORE] Seeded category default: ${category}`);
    } else {
      console.log(`  [DRY-RUN] Category Default: ${category} (24-hr profile, Confidence: low)`);
    }
  }

  // 3. Seed Holidays Table
  console.log(`\nSeeding ${DEFAULT_HOLIDAYS.length} national holidays...`);
  for (const holiday of DEFAULT_HOLIDAYS) {
    if (db) {
      await db.collection('holidays').doc(holiday.date).set(holiday, { merge: true });
      console.log(`  [FIRESTORE] Seeded holiday: ${holiday.date} (${holiday.name})`);
    } else {
      console.log(`  [DRY-RUN] Holiday: ${holiday.date} - ${holiday.name} (Multiplier: ${holiday.multiplier})`);
    }
  }

  console.log('\nSeed completed successfully!');
}

seedCrowdData().catch((err) => {
  console.error('Error during seed:', err);
  process.exit(1);
});

