import pino from 'pino';
import { env, isProd, isTest } from '../config/env';

export const logger = pino({
  level: env.LOG_LEVEL,
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      '*.password',
      '*.oldPassword',
      '*.newPassword',
      '*.confirmPassword',
      '*.refreshToken',
      '*.accessToken',
    ],
    censor: '[REDACTED]',
  },
  ...(isProd || isTest
    ? {}
    : { transport: { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:HH:MM:ss' } } }),
});
