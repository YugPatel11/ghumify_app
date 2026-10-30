import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, resolveLanguage } from '@/lib/language-resolution';

export async function POST(request: NextRequest) {
  const ip = request.headers.get('x-forwarded-for') || '127.0.0.1';

  const rate = checkRateLimit(`chat_${ip}`, 60, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many chat messages. Please wait a moment.' },
      { status: 429 }
    );
  }

  const userId = request.headers.get('x-user-id') || 'user_demo';
  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON body.' },
      { status: 400 }
    );
  }

  const { message, history = [], context = {}, language } = body || {};
  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return NextResponse.json(
      { code: 'EMPTY_MESSAGE', error: 'Field "message" cannot be empty.' },
      { status: 400 }
    );
  }

  const resolvedLang = language || resolveLanguage({
    userId,
    acceptLanguageHeader: request.headers.get('accept-language'),
    headerLang: request.headers.get('x-language'),
  });

  const keys = [
    process.env.GEMINI_API_KEY_1,
    process.env.GEMINI_API_KEY_2,
    process.env.GEMINI_API_KEY_3,
    process.env.GEMINI_API_KEY_4,
    process.env.GEMINI_API_KEY_5,
    process.env.GEMINI_API_KEY_6,
    process.env.GEMINI_API_KEY_7,
    process.env.GEMINI_API_KEY_8,
    process.env.GEMINI_API_KEY,
  ].filter((k): k is string => Boolean(k && k.length > 5 && !k.startsWith('YOUR_')));

  const systemPrompt = `You are "Ghumify AI", a knowledgeable, friendly, and joyful local travel companion for exploring Indian cities.
Help travelers with itineraries, tourist spots, famous local food, bazaars, cultural context, transport tips, and timings.
Always reply directly in the user's preferred language code: "${resolvedLang}".
Keep your answers helpful, concise, engaging, and well-structured with bullet points where appropriate.`;

  const contents = [
    { role: 'user', parts: [{ text: systemPrompt }] },
    { role: 'model', parts: [{ text: `Understood! I am Ghumify AI, your joyful travel companion. I will assist you in ${resolvedLang}.` }] },
  ];

  // Add conversation history
  if (Array.isArray(history)) {
    for (const h of history.slice(-8)) {
      if (h.role && h.text) {
        contents.push({
          role: h.role === 'assistant' || h.role === 'model' ? 'model' : 'user',
          parts: [{ text: h.text }],
        });
      }
    }
  }

  // Add current message with optional itinerary context
  let userText = message;
  if (context?.cityName) {
    userText = `[Context: Traveler is planning a trip in ${context.cityName}${context.hours ? ` for ${context.hours} hours` : ''}]\n${message}`;
  }
  contents.push({ role: 'user', parts: [{ text: userText }] });

  for (const key of keys) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 600,
          },
        }),
      });

      if (!res.ok) continue;

      const data = await res.json();
      const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (reply) {
        return NextResponse.json({
          success: true,
          response: reply.trim(),
          language: resolvedLang,
        });
      }
    } catch {}
  }

  // Graceful fallback response if all keys fail
  return NextResponse.json({
    success: true,
    response: `Thank you for asking! I'm here to help you explore the best places, food, and culture in your city. What specific recommendations would you like?`,
    language: resolvedLang,
  });
}
