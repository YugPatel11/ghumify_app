import { AIProvider, AITaskType } from './types';

export class GeminiAIProvider implements AIProvider {
  readonly name = 'gemini';

  private getKeys(): string[] {
    return [
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
  }

  private getModels(): string[] {
    const chain = process.env.GEMINI_MODEL_CHAIN || 'gemini-2.5-flash,gemini-1.5-flash';
    return chain.split(',').map((m) => m.trim()).filter(Boolean);
  }

  isAvailable(): boolean {
    return this.getKeys().length > 0 && this.getModels().length > 0;
  }

  private getConfig(taskType: AITaskType): { temperature: number; maxOutputTokens: number } {
    switch (taskType) {
      case 'complexPlanning':
        return { temperature: 0.6, maxOutputTokens: 16384 };
      case 'fastModification':
        return { temperature: 0.5, maxOutputTokens: 8192 };
      case 'chat':
        return { temperature: 0.8, maxOutputTokens: 4096 };
      case 'generalQuestion':
        return { temperature: 0.7, maxOutputTokens: 2048 };
      case 'placeInfo':
        return { temperature: 0.8, maxOutputTokens: 1024 };
      case 'translation':
        return { temperature: 0.3, maxOutputTokens: 2048 };
      default:
        return { temperature: 0.7, maxOutputTokens: 4096 };
    }
  }

  async generate(
    prompt: string,
    taskType: AITaskType,
    conversationHistory?: Array<{ role: string; content: string }>
  ): Promise<string> {
    const keys = this.getKeys();
    const models = this.getModels();
    const config = this.getConfig(taskType);

    if (keys.length === 0) throw new Error('No Gemini API keys configured.');
    if (models.length === 0) throw new Error('No Gemini models configured in GEMINI_MODEL_CHAIN.');

    const contents: any[] = [];
    if (conversationHistory && conversationHistory.length > 0) {
      for (const msg of conversationHistory) {
        contents.push({
          role: msg.role === 'user' ? 'user' : 'model',
          parts: [{ text: msg.content }],
        });
      }
    }
    contents.push({
      role: 'user',
      parts: [{ text: prompt }],
    });

    let lastError: Error | null = null;

    for (const model of models) {
      for (const key of keys) {
        try {
          const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
          const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents,
              generationConfig: {
                temperature: config.temperature,
                maxOutputTokens: config.maxOutputTokens,
              },
            }),
            signal: AbortSignal.timeout(15000), // 15s per-provider timeout
          });

          if (!res.ok) {
            const status = res.status;
            // If 429, 5xx, or 404, try next key or model
            if (status === 429 || status >= 500) {
              lastError = new Error(`Gemini status ${status}`);
              continue;
            }
            if (status === 404) {
              lastError = new Error(`Gemini model ${model} not found`);
              break; // Skip to next model
            }
            // 4xx client error
            lastError = new Error(`Gemini client error ${status}`);
            continue;
          }

          const data = await res.json();
          const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (candidateText && candidateText.trim().length > 0) {
            return candidateText.trim();
          }
          lastError = new Error('Empty Gemini candidate text');
        } catch (err: any) {
          lastError = err;
        }
      }
    }

    throw lastError || new Error('All Gemini models and keys exhausted');
  }
}

