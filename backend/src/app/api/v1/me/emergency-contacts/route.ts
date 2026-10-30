import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { SmsProvider } from '@/lib/sos/sms-provider';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare(`
      SELECT id, name, phone_e164, relationship, priority, preferred_channels,
             language, email, is_verified, verified_at, created_at, updated_at
      FROM emergency_contacts
      WHERE user_id = ?
      ORDER BY priority ASC
    `);
    const contacts = stmt.all(userId) as any[];

    return NextResponse.json({
      success: true,
      contacts: contacts.map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone_e164,
        relationship: c.relationship,
        priority: c.priority,
        preferredChannels: c.preferred_channels.split(','),
        language: c.language,
        email: c.email,
        isVerified: Boolean(c.is_verified),
        verifiedAt: c.verified_at,
        createdAt: c.created_at,
      })),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_CONTACTS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const {
      userId = 'user_demo',
      name,
      phone,
      relationship = 'Family',
      priority,
      preferredChannels = ['sms', 'push'],
      language = 'en',
      email,
    } = body;

    if (!name || !phone) {
      return NextResponse.json(
        { code: 'MISSING_FIELDS', error: 'Name and phone number are required.' },
        { status: 400 }
      );
    }

    // Validate and normalize phone
    const { isValid, e164, error: phoneErr } = SmsProvider.normalizePhone(phone);
    if (!isValid) {
      return NextResponse.json(
        { code: 'INVALID_PHONE', error: phoneErr || 'Invalid phone number format.' },
        { status: 400 }
      );
    }

    const db = getDb();

    // Enforce max 5 contacts
    const countStmt = db.prepare('SELECT count(*) as count FROM emergency_contacts WHERE user_id = ?');
    const currentCount = (countStmt.get(userId) as any)?.count || 0;
    if (currentCount >= 5) {
      return NextResponse.json(
        { code: 'MAX_CONTACTS_REACHED', error: 'Maximum of 5 emergency contacts reached.' },
        { status: 400 }
      );
    }

    // Check duplicate phone
    const duplicateStmt = db.prepare('SELECT id FROM emergency_contacts WHERE user_id = ? AND phone_e164 = ?');
    if (duplicateStmt.get(userId, e164)) {
      return NextResponse.json(
        { code: 'DUPLICATE_PHONE', error: 'This contact number has already been added.' },
        { status: 400 }
      );
    }

    const contactId = `contact_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    const nowIso = new Date().toISOString();
    const channelsStr = Array.isArray(preferredChannels) ? preferredChannels.join(',') : 'sms,push';
    const finalPriority = priority ?? currentCount + 1;

    const insertStmt = db.prepare(`
      INSERT INTO emergency_contacts (
        id, user_id, name, phone_e164, relationship, priority, preferred_channels,
        language, email, is_verified, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    `);
    insertStmt.run(contactId, userId, name.trim(), e164, relationship, finalPriority, channelsStr, language, email || null, nowIso, nowIso);

    return NextResponse.json({
      success: true,
      message: 'Emergency contact added successfully.',
      contact: {
        id: contactId,
        name: name.trim(),
        phone: e164,
        relationship,
        priority: finalPriority,
        preferredChannels: channelsStr.split(','),
        language,
        isVerified: false,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'ADD_CONTACT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const { id, name, relationship, priority, preferredChannels, language, email } = body;

    if (!id) {
      return NextResponse.json({ code: 'ID_REQUIRED', error: 'Contact ID is required.' }, { status: 400 });
    }

    const db = getDb();
    const nowIso = new Date().toISOString();
    const channelsStr = Array.isArray(preferredChannels) ? preferredChannels.join(',') : undefined;

    const updateStmt = db.prepare(`
      UPDATE emergency_contacts
      SET name = COALESCE(?, name),
          relationship = COALESCE(?, relationship),
          priority = COALESCE(?, priority),
          preferred_channels = COALESCE(?, preferred_channels),
          language = COALESCE(?, language),
          email = COALESCE(?, email),
          updated_at = ?
      WHERE id = ?
    `);
    const res = updateStmt.run(name || null, relationship || null, priority || null, channelsStr || null, language || null, email || null, nowIso, id);

    return NextResponse.json({
      success: true,
      updated: res.changes > 0,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'UPDATE_CONTACT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function DELETE(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    if (!id) {
      return NextResponse.json({ code: 'ID_REQUIRED', error: 'Contact ID query parameter required.' }, { status: 400 });
    }

    const db = getDb();
    const deleteStmt = db.prepare('DELETE FROM emergency_contacts WHERE id = ?');
    const res = deleteStmt.run(id);

    return NextResponse.json({
      success: true,
      deleted: res.changes > 0,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'DELETE_CONTACT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
