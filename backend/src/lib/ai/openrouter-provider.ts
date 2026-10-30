import { AIProvider, AITaskType } from './types';

export class OpenRouterAIProvider implements AIProvider {
  readonly name = 'openrouter';

  private getApiKey(): string {
    return process.env.OPENROUTER_API_KEY || '';
  }

  private getModels(): string[] {
    const envModels = process.env.OPENROUTER_MODELS || 'anthropic/claude-3.5-haiku,meta-llama/llama-3.3-70b-instruct';
    return envModels.split(',').map((m) => m.trim()).filter(Boolean);
  }

  isAvailable(): boolean {
    const key = this.getApiKey();
    return Boolean(key && key.length > 5 && !key.startsWith('YOUR_'));
  }

  private getConfig(taskType: AITaskType): { temperature: number; maxOutputTokens: number } {
    switch (taskType) {
      case 'complexPlanning':
        return { temperature: 0.5, maxOutputTokens: 8000 };
      case 'fastModification':
        return { temperature: 0.4, maxOutputTokens: 4096 };
      case 'chat':
        return { temperature: 0.7, maxOutputTokens: 2048 };
      case 'generalQuestion':
        return { temperature: 0.6, maxOutputTokens: 1024 };
      case 'placeInfo':
        return { temperature: 0.7, maxOutputTokens: 1024 };
      case 'translation':
        return { temperature: 0.2, maxOutputTokens: 2048 };
      default:
        return { temperature: 0.6, maxOutputTokens: 2048 };
    }
  }

  async generate(
    prompt: string,
    taskType: AITaskType,
    conversationHistory?: Array<{ role: string; content: string }>
  ): Promise<string> {
    if (!this.isAvailable()) throw new Error('OpenRouter API is not configured.');

    const apiKey = this.getApiKey();
    const models = this.getModels();
    const config = this.getConfig(taskType);

    const messages: Array<{ role: string; content: string }> = [];

    if (conversationHistory && conversationHistory.length > 0) {
      for (const msg of conversationHistory) {
        messages.push({
          role: msg.role === 'model' || msg.role === 'assistant' ? 'assistant' : 'user',
          content: msg.content,
        });
      }
    }
    messages.push({
      role: 'user',
      content: prompt,
    });

    let lastError: Error | null = null;

    for (const model of models) {
      try {
        const body: any = {
          model,
          messages,
          temperature: config.temperature,
          max_tokens: config.maxOutputTokens,
        };

        const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ghumify.app',
            'X-Title': 'Ghumify AI',
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(15000), // 15s timeout
        });

        if (!res.ok) {
          const errText = await res.text().catch(() => '');
          lastError = new Error(`OpenRouter (${model}) status ${res.status}: ${errText.slice(0, 200)}`);
          continue;
        }

        const data = await res.json();
        const content = data.choices?.[0]?.message?.content;
        if (content && typeof content === 'string' && content.trim().length > 0) {
          return content.trim();
        }
        lastError = new Error(`OpenRouter (${model}) returned empty content`);
      } catch (err: any) {
        lastError = err;
      }
    }

    throw lastError || new Error('All OpenRouter models exhausted');
  }
}

