import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import type { Role } from '@prisma/client';
import { env } from '../config/env';
import { redis } from './redis';
import { logger } from './logger';

export interface AccessClaims {
  sub: string;
  role: Role;
  uid: string;
  /** Password version (ms timestamp of last password change, 0 if never). */
  pv: number;
  iat: number;
  exp: number;
}

export interface TokenSubject {
  id: string;
  role: Role;
  unifiedId: string;
  passwordChangedAt?: Date | null;
}

export function signAccessToken(user: TokenSubject): string {
  const pv = user.passwordChangedAt ? user.passwordChangedAt.getTime() : 0;
  return jwt.sign({ role: user.role, uid: user.unifiedId, pv }, env.JWT_ACCESS_SECRET, {
    algorithm: 'HS256',
    subject: user.id,
    expiresIn: env.JWT_ACCESS_TTL as jwt.SignOptions['expiresIn'],
    issuer: env.JWT_ISSUER,
    audience: env.JWT_AUDIENCE,
    jwtid: crypto.randomUUID(),
  });
}

/** Throws on invalid/expired tokens. Algorithm is pinned to prevent alg-confusion attacks. */
export function verifyAccessToken(token: string): AccessClaims {
  const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
    algorithms: ['HS256'],
    issuer: env.JWT_ISSUER,
    audience: env.JWT_AUDIENCE,
  });
  if (typeof decoded === 'string' || !decoded.sub) throw new Error('malformed token');
  return decoded as unknown as AccessClaims;
}

let ttlCache: number | undefined;
/** Lifetime of access tokens in seconds (used for revocation TTLs). */
export function accessTtlSeconds(): number {
  if (ttlCache === undefined) {
    const probe = jwt.decode(signAccessToken({ id: '0', role: 'TRADER', unifiedId: '0' })) as { iat: number; exp: number };
    ttlCache = probe.exp - probe.iat;
  }
  return ttlCache;
}

export function newRefreshToken(): { raw: string; hash: string } {
  const raw = crypto.randomBytes(48).toString('base64url');
  return { raw, hash: hashToken(raw) };
}

export function hashToken(raw: string): string {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

const pwdVersionKey = (userId: string) => `auth:pwd-version:${userId}`;

/**
 * After a password change, every access token carrying an older password version is rejected
 * (until it would have expired anyway). Refresh tokens are revoked separately in Postgres.
 */
export async function publishPasswordVersion(userId: string, changedAt: Date): Promise<void> {
  await redis.set(pwdVersionKey(userId), String(changedAt.getTime()), 'EX', accessTtlSeconds() + 60);
}

export async function isAccessTokenRevoked(userId: string, pv: number | undefined): Promise<boolean> {
  try {
    const current = await redis.get(pwdVersionKey(userId));
    return current != null && Number(current) !== (pv ?? 0);
  } catch (err) {
    // Fail open on Redis outage: access tokens are short-lived and refresh tokens are revoked in Postgres.
    logger.warn({ err: (err as Error).message }, 'revocation check unavailable');
    return false;
  }
}
