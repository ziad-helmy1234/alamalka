import { OpenApiGeneratorV3 } from '@asteasolutions/zod-to-openapi';
import { registry } from './registry';

let cached: ReturnType<OpenApiGeneratorV3['generateDocument']> | undefined;

export function openApiDocument() {
  cached ??= new OpenApiGeneratorV3(registry.definitions).generateDocument({
    openapi: '3.0.3',
    info: {
      title: 'Amalka EGX Trading API',
      version: '1.0.0',
      description: [
        'Backend for the Amalka Egyptian Exchange (EGX) trading app.',
        '',
        '**Auth:** `POST /api/v1/auth/login` → send `Authorization: Bearer <accessToken>`. Access tokens last 15 min; rotate with `/auth/refresh` (refresh tokens are single-use).',
        '',
        '**Money:** all amounts and prices are decimal strings (never floats).',
        '',
        '**WebSocket:** `ws(s)://<host>/ws/live-stocks`. Send `{"action":"auth","token":"<accessToken>"}` for private events, then `{"action":"subscribe","symbols":["COMI","TMGH"]}` (or `["*"]`).',
        'Server events: `tick`, `order_update`, `trade_execution`, `price_alert`, `wallet_update`, `auth_expired`.',
      ].join('\n'),
    },
    servers: [{ url: '/' }],
    tags: [
      { name: 'Auth' },
      { name: 'Stocks' },
      { name: 'Portfolio' },
      { name: 'Orders' },
      { name: 'Payments' },
      { name: 'Price Alerts' },
      { name: 'Admin' },
      { name: 'System' },
    ],
  });
  return cached;
}
