import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { isLanguageSupported, getLanguageMetadata } from '@/lib/languages';

function getAuthenticatedUserId(req: NextRequest): string | null {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  const customHeader = req.headers.get('x-user-id');
  if (customHeader) {
    return customHeader.trim();
  }
  // In demo/test environment, default to seeded user_demo
  return 'user_demo';
}

export async function GET(request: NextRequest) {
  const userId = getAuthenticatedUserId(request);
  if (!userId) {
    return NextResponse.json(
      { code: 'UNAUTHORIZED', error: 'Authentication required.' },
      { status: 401 }
    );
  }

  const db = getDb();
  const row = db.prepare('SELECT id, name, email, preferred_language, created_at, updated_at FROM users WHERE id = ?').get(userId) as any;

  if (!row) {
    return NextResponse.json(
      { code: 'NOT_FOUND', error: 'User profile not found.' },
      { status: 404 }
    );
  }

  const meta = getLanguageMetadata(row.preferred_language);

  return NextResponse.json({
    success: true,
    data: {
      userId: row.id,
      name: row.name,
      email: row.email,
      preferred_language: row.preferred_language,
      language_details: meta,
      updated_at: row.updated_at,
    },
  });
}

export async function PUT(request: NextRequest) {
  const userId = getAuthenticatedUserId(request);
  if (!userId) {
    return NextResponse.json(
      { code: 'UNAUTHORIZED', error: 'Authentication required.' },
      { status: 401 }
    );
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON request payload.' },
      { status: 400 }
    );
  }

  const { language } = body || {};

  if (!language || typeof language !== 'string') {
    return NextResponse.json(
      { code: 'MISSING_FIELD', error: 'Field "language" is required and must be a string.' },
      { status: 400 }
    );
  }

  const trimmedLang = language.trim().toLowerCase();

  if (!isLanguageSupported(trimmedLang)) {
    return NextResponse.json(
      { code: 'UNSUPPORTED_LANGUAGE', error: `Language "${trimmedLang}" is not in the supported languages list.` },
      { status: 400 }
    );
  }

  const db = getDb();
  const now = new Date().toISOString();

  // Upsert user if needed
  const userCheck = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
  if (!userCheck) {
    db.prepare(`
      INSERT INTO users (id, name, email, preferred_language, created_at, updated_at)
      VALUES (?, 'Traveler', 'traveler@ghumify.app', ?, ?, ?)
    `).run(userId, trimmedLang, now, now);
  } else {
    db.prepare(`
      UPDATE users 
      SET preferred_language = ?, updated_at = ?
      WHERE id = ?
    `).run(trimmedLang, now, userId);
  }

  const updatedUser = db.prepare('SELECT id, name, email, preferred_language, updated_at FROM users WHERE id = ?').get(userId) as any;
  const meta = getLanguageMetadata(trimmedLang);

  return NextResponse.json({
    success: true,
    message: 'User preferred language updated successfully.',
    data: {
      userId: updatedUser.id,
      name: updatedUser.name,
      email: updatedUser.email,
      preferred_language: updatedUser.preferred_language,
      language_details: meta,
      updated_at: updatedUser.updated_at,
    },
  });
}
