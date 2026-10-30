export interface CircuitBreakerOptions {
  failureThreshold?: number;
  cooldownMs?: number;
}

export class CircuitBreaker {
  private failureThreshold: number;
  private cooldownMs: number;
  private failureCounts = new Map<string, number>();
  private openUntil = new Map<string, number>();

  constructor(options: CircuitBreakerOptions = {}) {
    this.failureThreshold = options.failureThreshold ?? 3;
    this.cooldownMs = options.cooldownMs ?? 60000; // 60 seconds
  }

  isAvailable(name: string): boolean {
    const until = this.openUntil.get(name) || 0;
    if (Date.now() < until) {
      return false;
    }
    return true;
  }

  recordSuccess(name: string): void {
    this.failureCounts.set(name, 0);
    this.openUntil.delete(name);
  }

  recordFailure(name: string): void {
    const current = (this.failureCounts.get(name) || 0) + 1;
    this.failureCounts.set(name, current);

    if (current >= this.failureThreshold) {
      this.openUntil.set(name, Date.now() + this.cooldownMs);
    }
  }

  getCooldownRemainingSeconds(name: string): number {
    const until = this.openUntil.get(name) || 0;
    const diff = until - Date.now();
    return diff > 0 ? Math.ceil(diff / 1000) : 0;
  }

  reset(name?: string): void {
    if (name) {
      this.failureCounts.delete(name);
      this.openUntil.delete(name);
    } else {
      this.failureCounts.clear();
      this.openUntil.clear();
    }
  }
}

