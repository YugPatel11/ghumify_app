export type AITaskType =
  | 'complexPlanning'
  | 'fastModification'
  | 'chat'
  | 'generalQuestion'
  | 'placeInfo'
  | 'translation';

export interface AIProvider {
  readonly name: string;
  isAvailable(): boolean;
  generate(
    prompt: string,
    taskType: AITaskType,
    conversationHistory?: Array<{ role: string; content: string }>
  ): Promise<string>;
}

export interface AIRouteResult {
  content: string;
  provider: string;
  isDegraded: boolean;
}

