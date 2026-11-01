import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import { Prisma, type User } from '@prisma/client';
import { env } from '../../config/env';
import { prisma, withTx } from '../../lib/prisma';
import { redis } from '../../lib/redis';
import { AppError, Conflict, Unauthorized } from '../../lib/errors';
import { logger } from '../../lib/logger';
import {
  accessTtlSeconds,
  hashToken,
  newRefreshToken,
  publishPasswordVersion,
  signAccessToken,
} from '../../lib/tokens';

// Used to keep login timing identical whether or not the email exists (prevents user enumeration).
const DUMMY_HASH = bcrypt.hashSync('timing-equaliser-not-a-real-password', 10);

const MAX_FAILED_LOGINS = 5;
const LOCKOUT_SECONDS = 15 * 60;

interface ClientMeta {
  ip?: string;
  userAgent?: string;
}

export function toUserDto(u: User) {
  return {
    id: u.id,
    email: u.email,
    fullNameAr: u.fullNameAr,
    fullNameEn: u.fullNameEn,
    unifiedId: u.unifiedId,
    role: u.role,
    createdAt: u.createdAt.toISOString(),
  };
}

async function issueTokens(user: User, meta: ClientMeta, familyId: string = crypto.randomUUID(), tx: Prisma.TransactionClient = prisma) {
  const refresh = newRefreshToken();
  await tx.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: refresh.hash,
      familyId,
      expiresAt: new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 86_400_000),
      ip: meta.ip?.slice(0, 64),
      userAgent: meta.userAgent?.slice(0, 255),
    },
  });
  return {
    user: toUserDto(user),
    accessToken: signAccessToken(user),
    refreshToken: refresh.raw,
    tokenType: 'Bearer' as const,
    expiresIn: accessTtlSeconds(),
  };
}

export async function register(
  input: { email: string; password: string; fullNameAr: string; fullNameEn: string },
  meta: ClientMeta,
) {
  const passwordHash = await bcrypt.hash(input.password, env.BCRYPT_ROUNDS);
  try {
    return await withTx(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: input.email,
          passwordHash,
          fullNameAr: input.fullNameAr,
          fullNameEn: input.fullNameEn,
          // One wallet per currency, created atomically with the user.
          portfolios: { create: [{ currency: 'EGP' }, { currency: 'USD' }] },
        },
      });
      return issueTokens(user, meta, undefined, tx);
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      throw Conflict('EMAIL_TAKEN', 'An account with this email already exists');
    }
    throw err;
  }
}

export async function login(input: { email: string; password: string }, meta: ClientMeta) {
  const lockKey = `auth:fail:${input.email}`;
  const failures = Number((await redis.get(lockKey).catch(() => null)) ?? 0);
  if (failures >= MAX_FAILED_LOGINS) {
    throw new AppError(429, 'ACCOUNT_LOCKED', 'Too many failed attempts. Try again in 15 minutes.');
  }

  const user = await prisma.user.findUnique({ where: { email: input.email } });
  const ok = await bcrypt.compare(input.password, user?.passwordHash ?? DUMMY_HASH);

  if (!user || !ok) {
    await redis.multi().incr(lockKey).expire(lockKey, LOCKOUT_SECONDS).exec().catch(() => undefined);
    logger.info({ email: input.email, ip: meta.ip }, 'failed login');
    throw Unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
  }

  await redis.del(lockKey).catch(() => undefined);
  return issueTokens(user, meta);
}

/**
 * Refresh-token rotation with reuse detection: each refresh token is single-use.
 * Presenting an already-rotated token means it was stolen (or replayed), so the
 * whole token family is revoked and the user must sign in again.
 */
export async function refresh(rawToken: string, meta: ClientMeta) {
  const tokenHash = hashToken(rawToken);
  const existing = await prisma.refreshToken.findUnique({ where: { tokenHash }, include: { user: true } });
  if (!existing) throw Unauthorized('Invalid refresh token', 'INVALID_REFRESH_TOKEN');

  if (existing.revokedAt || existing.rotatedAt) {
    await prisma.refreshToken.updateMany({
      where: { familyId: existing.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    logger.warn({ userId: existing.userId, familyId: existing.familyId }, 'refresh token reuse detected — family revoked');
    throw Unauthorized('Refresh token has been revoked', 'REFRESH_TOKEN_REUSED');
  }
  if (existing.expiresAt < new Date()) throw Unauthorized('Refresh token expired', 'REFRESH_TOKEN_EXPIRED');

  return withTx(async (tx) => {
    // Conditional update makes concurrent refreshes with the same token race-safe: only one wins.
    const claimed = await tx.refreshToken.updateMany({
      where: { id: existing.id, rotatedAt: null, revokedAt: null },
      data: { rotatedAt: new Date() },
    });
    if (claimed.count !== 1) throw Unauthorized('Refresh token has been revoked', 'REFRESH_TOKEN_REUSED');
    return issueTokens(existing.user, meta, existing.familyId, tx);
  });
}

export async function logout(rawToken: string) {
  const existing = await prisma.refreshToken.findUnique({ where: { tokenHash: hashToken(rawToken) } });
  if (existing) {
    await prisma.refreshToken.updateMany({
      where: { familyId: existing.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}

export async function changePassword(userId: string, oldPassword: string, newPassword: string, meta: ClientMeta) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw Unauthorized();
  if (!(await bcrypt.compare(oldPassword, user.passwordHash))) {
    throw Unauthorized('Current password is incorrect', 'INVALID_CREDENTIALS');
  }
  const passwordHash = await bcrypt.hash(newPassword, env.BCRYPT_ROUNDS);
  const changedAt = new Date();

  const result = await withTx(async (tx) => {
    const updated = await tx.user.update({ where: { id: userId }, data: { passwordHash, passwordChangedAt: changedAt } });
    // Sign out every other device.
    await tx.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: changedAt } });
    return issueTokens(updated, meta, undefined, tx);
  });

  await publishPasswordVersion(userId, changedAt);
  return { message: 'Password changed. Other sessions have been signed out.', ...result };
}
