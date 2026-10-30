import { AIProvider, AITaskType } from './types';

export class GroqAIProvider implements AIProvider {
  readonly name = 'groq';

  private getApiKey(): string {
    return process.env.GROQ_API_KEY || '';
  }

  private getModel(): string {
    return process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
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
    if (!this.isAvailable()) throw new Error('Groq API is not configured.');

    const apiKey = this.getApiKey();
    const model = this.getModel();
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

    const isPlanning = taskType === 'complexPlanning' || taskType === 'fastModification';
    const body: any = {
      model,
      messages,
      temperature: config.temperature,
      max_tokens: config.maxOutputTokens,
    };

    if (isPlanning) {
      body.response_format = { type: 'json_object' };
    }

    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15000), // 15s per-provider timeout
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => '');
      throw new Error(`Groq API error (${res.status}): ${errText.slice(0, 200)}`);
    }

    const data = await res.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content || typeof content !== 'string' || content.trim().length === 0) {
      throw new Error('Empty response from Groq');
    }

    return content.trim();
  }
}

