import { NextResponse } from 'next/server';
import crypto from 'node:crypto';
import { getDb } from '@/lib/db';
import { SmsProvider } from '@/lib/sos/sms-provider';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: contactId } = await params;
    const db = getDb();

    const contactStmt = db.prepare('SELECT * FROM emergency_contacts WHERE id = ?');
    const contact = contactStmt.get(contactId) as any;

    if (!contact) {
      return NextResponse.json({ code: 'CONTACT_NOT_FOUND', error: 'Emergency contact not found.' }, { status: 404 });
    }

    // Generate 6-digit code and store SHA-256 hash
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = crypto.createHash('sha256').update(otp).digest('hex');
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 min TTL
    const nowIso = new Date().toISOString();

    const insertCode = db.prepare(`
      INSERT INTO emergency_contact_verifications (id, contact_id, code_hash, expires_at, attempts, created_at)
      VALUES (?, ?, ?, ?, 0, ?)
    `);
    const verifId = `v_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
    insertCode.run(verifId, contactId, codeHash, expiresAt, nowIso);

    // Send SMS with verification code
    const msg = `Ghumify: Your verification code to confirm you as an emergency contact is ${otp}. Valid for 10 minutes.`;
    const sendRes = await SmsProvider.send({
      to: contact.phone_e164,
      body: msg,
    });

    return NextResponse.json({
      success: true,
      message: 'Verification code sent.',
      verificationId: verifId,
      expiresAt,
      isSimulated: sendRes.isSimulated,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'VERIFICATION_REQUEST_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
