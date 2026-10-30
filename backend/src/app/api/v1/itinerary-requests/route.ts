import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { mergeFormAndRemarks, FormFields } from '@/lib/planner/remarks-merger';
import { resolveLanguage } from '@/lib/language-resolution';

export async function POST(request: NextRequest) {
  try {
    const requestUrl = new URL(request.url);
    const lang = resolveLanguage({
      headerLang: request.headers.get('x-language'),
      acceptLanguageHeader: request.headers.get('accept-language'),
      queryLang: requestUrl.searchParams.get('lang'),
    });

    let body: any;
    try {
      body = await request.json();
    } catch {
      return NextResponse.json(
        { code: 'INVALID_JSON', error: 'Invalid JSON payload.' },
        { status: 400 }
      );
    }

    const {
      form_fields = {},
      remarks,
      language = lang,
      idempotency_key = `req_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      user_id = 'user_demo',
    } = body || {};

    const db = getDb();

    // 1. Check idempotency: if request with idempotency_key exists, return stored result
    const checkStmt = db.prepare('SELECT * FROM itinerary_requests WHERE idempotency_key = ?');
    const existing = checkStmt.get(idempotency_key) as any;
    if (existing) {
      return NextResponse.json({
        success: true,
        idempotent: true,
        idempotency_key,
        plan: JSON.parse(existing.merged_plan),
        is_fast_path: !existing.remarks || existing.remarks.trim().length === 0,
        contradictions: JSON.parse(existing.merged_plan).contradictions || [],
        sources: JSON.parse(existing.merged_plan).sources || {},
        created_at: existing.created_at,
      });
    }

    // 2. Execute Form & Remarks Merge Engine
    const mergeResult = mergeFormAndRemarks(form_fields as FormFields, remarks, language);
    if (!mergeResult.valid || !mergeResult.plan) {
      return NextResponse.json(
        {
          code: 'MISSING_REQUIRED_DATA',
          error: mergeResult.errorMessage || 'Please provide required trip details.',
          missing_fields: mergeResult.missingFields,
        },
        { status: 400 }
      );
    }

    const plan = mergeResult.plan;
    const nowIso = new Date().toISOString();

    // 3. Store request for idempotency and audit trail
    const insertStmt = db.prepare(`
      INSERT INTO itinerary_requests (
        idempotency_key, user_id, city, form_fields, remarks, merged_plan, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'completed', ?)
    `);

    insertStmt.run(
      idempotency_key,
      user_id,
      plan.city,
      JSON.stringify(form_fields),
      remarks || null,
      JSON.stringify(plan),
      nowIso
    );

    // 4. Return merged draft plan with contradictions and sources
    return NextResponse.json({
      success: true,
      idempotent: false,
      idempotency_key,
      plan,
      is_fast_path: !plan.hasRemarks,
      contradictions: plan.contradictions,
      sources: plan.sources,
      assumptions: plan.assumptions,
      extracted_preferences: plan.extractedPreferences,
    });
  } catch (error: any) {
    console.error('[ItineraryRequestsAPI] Error merging form and remarks:', error);
    return NextResponse.json(
      { code: 'INTERNAL_ERROR', error: error.message || 'Failed to process itinerary request.' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const key = searchParams.get('key');
    if (!key) {
      return NextResponse.json({ code: 'MISSING_KEY', error: 'Query param "key" is required.' }, { status: 400 });
    }

    const db = getDb();
    const row = db.prepare('SELECT * FROM itinerary_requests WHERE idempotency_key = ?').get(key) as any;
    if (!row) {
      return NextResponse.json({ code: 'NOT_FOUND', error: 'Itinerary request not found.' }, { status: 404 });
    }

    return NextResponse.json({
      success: true,
      idempotency_key: row.idempotency_key,
      plan: JSON.parse(row.merged_plan),
      remarks: row.remarks,
      created_at: row.created_at,
    });
  } catch (error: any) {
    return NextResponse.json({ code: 'INTERNAL_ERROR', error: error.message }, { status: 500 });
  }
}
