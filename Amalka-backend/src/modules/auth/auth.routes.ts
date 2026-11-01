import { Router, type Request } from 'express';
import { env } from '../../config/env';
import { commonErrors, registry, secured, z } from '../../docs/registry';
import { requireAuth } from '../../middleware/auth';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { AuthResponse, ChangePasswordBody, LoginBody, RefreshBody, RegisterBody } from './auth.schemas';
import * as auth from './auth.service';

const meta = (req: Request) => ({ ip: req.ip, userAgent: req.get('user-agent') });
const authLimiter = rateLimit({ name: 'auth', limit: env.RATE_LIMIT_AUTH_PER_MIN });

export const authRouter = Router();

authRouter.post('/register', authLimiter, validate({ body: RegisterBody }), async (req, res) => {
  res.status(201).json(await auth.register(req.valid.body, meta(req)));
});

authRouter.post('/login', authLimiter, validate({ body: LoginBody }), async (req, res) => {
  res.json(await auth.login(req.valid.body, meta(req)));
});

authRouter.post('/refresh', authLimiter, validate({ body: RefreshBody }), async (req, res) => {
  res.json(await auth.refresh(req.valid.body.refreshToken, meta(req)));
});

authRouter.post('/logout', validate({ body: RefreshBody }), async (req, res) => {
  await auth.logout(req.valid.body.refreshToken);
  res.status(204).end();
});

authRouter.post('/change-password', requireAuth, authLimiter, validate({ body: ChangePasswordBody }), async (req, res) => {
  const { oldPassword, newPassword } = req.valid.body;
  res.json(await auth.changePassword(req.user!.id, oldPassword, newPassword, meta(req)));
});

// ---- OpenAPI ----
const json = <T extends z.ZodTypeAny>(schema: T) => ({ content: { 'application/json': { schema } } });
const base = '/api/v1/auth';

registry.registerPath({
  method: 'post', path: `${base}/register`, tags: ['Auth'],
  summary: 'Create an account (also creates EGP and USD wallets)',
  request: { body: json(RegisterBody) },
  responses: { 201: { description: 'Created', ...json(AuthResponse) }, 409: { description: 'Email already registered' }, ...commonErrors },
});
registry.registerPath({
  method: 'post', path: `${base}/login`, tags: ['Auth'], summary: 'Sign in',
  request: { body: json(LoginBody) },
  responses: { 200: { description: 'OK', ...json(AuthResponse) }, ...commonErrors },
});
registry.registerPath({
  method: 'post', path: `${base}/refresh`, tags: ['Auth'],
  summary: 'Rotate refresh token and get a new access token (refresh tokens are single-use)',
  request: { body: json(RefreshBody) },
  responses: { 200: { description: 'OK', ...json(AuthResponse) }, ...commonErrors },
});
registry.registerPath({
  method: 'post', path: `${base}/logout`, tags: ['Auth'], summary: 'Revoke the refresh token (and its session family)',
  request: { body: json(RefreshBody) },
  responses: { 204: { description: 'Signed out' } },
});
registry.registerPath({
  method: 'post', path: `${base}/change-password`, tags: ['Auth'], security: secured,
  summary: 'Change password; signs out all other sessions and returns fresh tokens',
  request: { body: json(ChangePasswordBody) },
  responses: { 200: { description: 'OK', ...json(AuthResponse.extend({ message: z.string() })) }, ...commonErrors },
});
