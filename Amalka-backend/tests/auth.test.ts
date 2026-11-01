import jwt from 'jsonwebtoken';
import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../src/lib/prisma';
import { app, registerUser, resetDb, uniqueEmail } from './helpers';

beforeEach(resetDb);

describe('auth', () => {
  it('registers a user with EGP + USD wallets and a unified id', async () => {
    const u = await registerUser();
    const portfolios = await prisma.portfolio.findMany({ where: { userId: u.id } });
    expect(portfolios.map((p) => p.currency).sort()).toEqual(['EGP', 'USD']);
    const user = await prisma.user.findUniqueOrThrow({ where: { id: u.id } });
    expect(user.unifiedId).toMatch(/^EGX-\d{6,}$/);
    expect(user.passwordHash).not.toContain('Passw0rd');
  });

  it('rejects duplicate emails (case-insensitive) and weak passwords', async () => {
    const u = await registerUser();
    const dup = await request(app).post('/api/v1/auth/register')
      .send({ email: u.email.toUpperCase(), password: 'Another1pass', fullNameAr: 'اسم', fullNameEn: 'Name' });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('EMAIL_TAKEN');

    const weak = await request(app).post('/api/v1/auth/register')
      .send({ email: uniqueEmail(), password: 'short', fullNameAr: 'اسم', fullNameEn: 'Name' });
    expect(weak.status).toBe(400);
    expect(weak.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('logs in, rejects bad credentials and locks out after repeated failures', async () => {
    const u = await registerUser();
    const ok = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: u.password });
    expect(ok.status).toBe(200);
    expect(ok.body.accessToken).toBeTruthy();

    for (let i = 0; i < 5; i++) {
      const bad = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'wrong-password1' });
      expect(bad.status).toBe(401);
    }
    const locked = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: u.password });
    expect(locked.status).toBe(429);
    expect(locked.body.error.code).toBe('ACCOUNT_LOCKED');
  });

  it('does not reveal whether an email exists', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: uniqueEmail('ghost'), password: 'whatever1' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('rotates refresh tokens and revokes the family on reuse', async () => {
    const u = await registerUser();
    const r1 = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken });
    expect(r1.status).toBe(200);
    expect(r1.body.refreshToken).not.toBe(u.refreshToken);

    // Replaying the old token = theft signal → whole family revoked
    const replay = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe('REFRESH_TOKEN_REUSED');

    const r2 = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken });
    expect(r2.status).toBe(401);
  });

  it('only one of two concurrent refreshes with the same token succeeds', async () => {
    const u = await registerUser();
    const [a, b] = await Promise.all([
      request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken }),
      request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken }),
    ]);
    expect([a.status, b.status].sort()).toEqual([200, 401]);
  });

  it('change-password validates input, revokes old sessions and access tokens', async () => {
    const u = await registerUser();

    const mismatch = await request(app).post('/api/v1/auth/change-password').set(u.auth)
      .send({ oldPassword: u.password, newPassword: 'NewPassw0rd', confirmPassword: 'Different1' });
    expect(mismatch.status).toBe(400);

    const wrongOld = await request(app).post('/api/v1/auth/change-password').set(u.auth)
      .send({ oldPassword: 'not-it-123', newPassword: 'NewPassw0rd', confirmPassword: 'NewPassw0rd' });
    expect(wrongOld.status).toBe(401);

    const ok = await request(app).post('/api/v1/auth/change-password').set(u.auth)
      .send({ oldPassword: u.password, newPassword: 'NewPassw0rd', confirmPassword: 'NewPassw0rd' });
    expect(ok.status).toBe(200);

    // old access token is now rejected, the new one works
    const oldTok = await request(app).get('/api/v1/portfolio/summary').set(u.auth);
    expect(oldTok.status).toBe(401);
    expect(oldTok.body.error.code).toBe('TOKEN_REVOKED');
    const newTok = await request(app).get('/api/v1/portfolio/summary').set('Authorization', `Bearer ${ok.body.accessToken}`);
    expect(newTok.status).toBe(200);

    // old refresh token revoked, old password no longer works
    expect((await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken })).status).toBe(401);
    expect((await request(app).post('/api/v1/auth/login').send({ email: u.email, password: u.password })).status).toBe(401);
    expect((await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'NewPassw0rd' })).status).toBe(200);
  });

  it('rejects missing, forged, alg=none and expired tokens', async () => {
    const u = await registerUser();
    expect((await request(app).get('/api/v1/portfolio/summary')).status).toBe(401);

    const forged = jwt.sign({ role: 'ADMIN', uid: 'x', pv: 0 }, 'some-other-secret-that-is-long-enough', {
      subject: u.id, issuer: 'amalka-backend', audience: 'amalka-app',
    });
    expect((await request(app).get('/api/v1/portfolio/summary').set('Authorization', `Bearer ${forged}`)).status).toBe(401);

    const [h, p] = u.accessToken.split('.');
    const none = `${Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url')}.${p}.`;
    expect((await request(app).get('/api/v1/portfolio/summary').set('Authorization', `Bearer ${none}`)).status).toBe(401);
    expect(h).toBeTruthy();

    const expired = jwt.sign({ role: 'TRADER', uid: 'x', pv: 0 }, process.env.JWT_ACCESS_SECRET!, {
      subject: u.id, issuer: 'amalka-backend', audience: 'amalka-app', expiresIn: -10,
    });
    const res = await request(app).get('/api/v1/portfolio/summary').set('Authorization', `Bearer ${expired}`);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TOKEN_EXPIRED');
  });

  it('logout revokes the refresh token', async () => {
    const u = await registerUser();
    expect((await request(app).post('/api/v1/auth/logout').send({ refreshToken: u.refreshToken })).status).toBe(204);
    expect((await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken })).status).toBe(401);
  });

  it('never returns the password hash and strips unknown fields', async () => {
    const res = await request(app).post('/api/v1/auth/register')
      .send({ email: uniqueEmail(), password: 'Passw0rd!', fullNameAr: 'اسم', fullNameEn: 'Name', role: 'ADMIN' });
    expect(res.status).toBe(400); // strict schema: cannot self-assign a role
    const ok = await request(app).post('/api/v1/auth/register')
      .send({ email: uniqueEmail(), password: 'Passw0rd!', fullNameAr: 'اسم', fullNameEn: 'Name' });
    expect(JSON.stringify(ok.body)).not.toContain('passwordHash');
    expect(ok.body.user.role).toBe('TRADER');
  });
});
