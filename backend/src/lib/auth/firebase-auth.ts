import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let firebaseInitialized = false;

function initFirebaseAdmin() {
  if (firebaseInitialized || getApps().length > 0) {
    firebaseInitialized = true;
    return;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    try {
      initializeApp({
        credential: cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
      firebaseInitialized = true;
    } catch (e) {
      console.warn('[FirebaseAuth] Failed to initialize Firebase Admin with credentials:', e);
    }
  } else {
    try {
      initializeApp();
      firebaseInitialized = true;
    } catch {
      // Allowed in development / tests
    }
  }
}

export async function verifyAuthToken(authHeader: string | null): Promise<{ valid: boolean; userId: string; error?: string }> {
  initFirebaseAdmin();

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    // Allow development fallback if FIREBASE_PROJECT_ID is not configured
    if (!process.env.FIREBASE_PROJECT_ID && process.env.NODE_ENV !== 'production') {
      return { valid: true, userId: 'user_dev_local' };
    }
    return { valid: false, userId: '', error: 'Missing or malformed Authorization header.' };
  }

  const token = authHeader.substring(7).trim();

  // In test / dev environment, allow bypass token
  if (process.env.NODE_ENV !== 'production' && token === 'test_token_user_demo') {
    return { valid: true, userId: 'user_demo' };
  }

  if (getApps().length === 0) {
    // If Firebase isn't configured in environment
    if (process.env.NODE_ENV !== 'production') {
      return { valid: true, userId: 'user_demo' };
    }
    return { valid: false, userId: '', error: 'Firebase Admin not configured on server.' };
  }

  try {
    const decoded = await getAuth().verifyIdToken(token);
    return { valid: true, userId: decoded.uid };
  } catch (err: any) {
    return { valid: false, userId: '', error: `Invalid ID token: ${err?.message || 'Verification failed'}` };
  }
}
