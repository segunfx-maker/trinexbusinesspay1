export interface RedisClient {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: "EX", ttlSeconds: number): Promise<unknown>;
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<unknown>;
  ttl(key: string): Promise<number>;
}

export function getRedis(): RedisClient | null {
  return null;
}

export async function getRedisStatus(): Promise<{
  configured: boolean;
  connected: boolean;
  latencyMs?: number;
}> {
  return { configured: false, connected: false };
}
