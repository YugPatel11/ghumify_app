import { NextResponse } from 'next/server';
import crypto from 'node:crypto';
import { getDb } from '@/lib/db';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: contactId } = await params;
    const body = await request.json();
    const { code } = body;

    if (!code) {
      return NextResponse.json({ code: 'CODE_REQUIRED', error: 'Verification code is required.' }, { status: 400 });
    }

    const db = getDb();
    const nowIso = new Date().toISOString();

    const verifStmt = db.prepare(`
      SELECT id, code_hash, expires_at, attempts
      FROM emergency_contact_verifications
      WHERE contact_id = ? AND expires_at > ?
      ORDER BY created_at DESC LIMIT 1
    `);
    const verification = verifStmt.get(contactId, nowIso) as any;

    if (!verification) {
      return NextResponse.json(
        { code: 'EXPIRED_OR_NOT_FOUND', error: 'Verification code expired or not found. Please request a new code.' },
        { status: 400 }
      );
    }

    if (verification.attempts >= 4) {
      return NextResponse.json(
        { code: 'MAX_ATTEMPTS_EXCEEDED', error: 'Too many incorrect attempts. Please request a new code.' },
        { status: 429 }
      );
    }

    const inputHash = crypto.createHash('sha256').update(code.trim()).digest('hex');

    if (inputHash !== verification.code_hash) {
      db.prepare('UPDATE emergency_contact_verifications SET attempts = attempts + 1 WHERE id = ?').run(verification.id);
      return NextResponse.json(
        { code: 'INVALID_CODE', error: 'Incorrect verification code.' },
        { status: 400 }
      );
    }

    // Code matches -> verify contact
    db.prepare(`
      UPDATE emergency_contacts
      SET is_verified = 1, verified_at = ?, updated_at = ?
      WHERE id = ?
    `).run(nowIso, nowIso, contactId);

    // Delete verification records
    db.prepare('DELETE FROM emergency_contact_verifications WHERE contact_id = ?').run(contactId);

    return NextResponse.json({
      success: true,
      message: 'Emergency contact successfully verified.',
      contactId,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'VERIFICATION_CONFIRM_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
