import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare('SELECT * FROM user_medical_profiles WHERE user_id = ?');
    const row = stmt.get(userId) as any;

    return NextResponse.json({
      success: true,
      profile: row
        ? {
            userId: row.user_id,
            bloodGroup: row.blood_group,
            allergies: row.allergies,
            medicalConditions: row.medical_conditions,
            medications: row.medications,
            includeInSos: Boolean(row.include_in_sos),
            updatedAt: row.updated_at,
          }
        : {
            userId,
            bloodGroup: '',
            allergies: '',
            medicalConditions: '',
            medications: '',
            includeInSos: false,
          },
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_MEDICAL_PROFILE_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const {
      userId = 'user_demo',
      bloodGroup = '',
      allergies = '',
      medicalConditions = '',
      medications = '',
      includeInSos = false,
    } = body;

    const db = getDb();
    const nowIso = new Date().toISOString();

    const upsertStmt = db.prepare(`
      INSERT INTO user_medical_profiles (
        user_id, blood_group, allergies, medical_conditions, medications, include_in_sos, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        blood_group = excluded.blood_group,
        allergies = excluded.allergies,
        medical_conditions = excluded.medical_conditions,
        medications = excluded.medications,
        include_in_sos = excluded.include_in_sos,
        updated_at = excluded.updated_at
    `);
    upsertStmt.run(
      userId,
      bloodGroup.trim(),
      allergies.trim(),
      medicalConditions.trim(),
      medications.trim(),
      includeInSos ? 1 : 0,
      nowIso
    );

    return NextResponse.json({
      success: true,
      message: 'Medical profile updated successfully.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'UPDATE_MEDICAL_PROFILE_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
