import { createHash } from "crypto";
import { getRedis, type RedisClient } from "./client";

const KEY_PREFIX = "trinex-businesspay";

export function buildCacheKey(namespace: string, parts: string[]): string {
  const normalized = [...parts].map((p) => p.toLowerCase()).sort();
  const digest = createHash("sha256").update(normalized.join("|")).digest("hex").slice(0, 16);
  return `${KEY_PREFIX}:cache:${namespace}:${digest}`;
}

export async function cacheGetJson<T>(
  key: string,
  redis: RedisClient | null = getRedis(),
): Promise<T | null> {
  if (!redis) return null;
  try {
    const raw = await redis.get(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch (err) {
    console.error("[trinex-businesspay][redis] cacheGetJson failed:", err);
    return null;
  }
}

export async function cacheSetJson(
  key: string,
  value: unknown,
  ttlSeconds: number,
  redis: RedisClient | null = getRedis(),
): Promise<void> {
  if (!redis) return;
  try {
    await redis.set(key, JSON.stringify(value), "EX", ttlSeconds);
  } catch (err) {
    console.error("[trinex-businesspay][redis] cacheSetJson failed:", err);
  }
}

export async function getOrSetJson<T>(
  key: string,
  ttlSeconds: number,
  loader: () => Promise<T>,
  redis: RedisClient | null = getRedis(),
): Promise<T> {
  const cached = await cacheGetJson<T>(key, redis);
  if (cached !== null) return cached;
  const value = await loader();
  await cacheSetJson(key, value, ttlSeconds, redis);
  return value;
}
