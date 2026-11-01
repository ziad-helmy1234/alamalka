import type { IncomingMessage, Server } from 'node:http';
import { WebSocket, WebSocketServer } from 'ws';
import { corsOrigins } from '../config/env';
import { logger } from '../lib/logger';
import { redisSub } from '../lib/redis';
import { isAccessTokenRevoked, verifyAccessToken } from '../lib/tokens';
import { CHANNELS, type TickPayload } from './events';

export const WS_PATH = '/ws/live-stocks';

const MAX_SYMBOLS = 200;
const MAX_MSGS_PER_10S = 50;
const HEARTBEAT_MS = 30_000;

interface Client {
  ws: WebSocket;
  userId: string | null;
  authTimer?: NodeJS.Timeout;
  symbols: Set<string>; // '*' = everything
  alive: boolean;
  msgCount: number;
  msgWindow: number;
}

/**
 * Live gateway.
 *  - Public: price ticks for subscribed symbols.
 *  - Authenticated (token via first "auth" message, or ?token= for clients that can't send one):
 *    order updates, trade executions, price-alert triggers, wallet updates for that user only.
 * Events arrive from Redis pub/sub, so any API instance can serve any client.
 */
export class LiveGateway {
  private wss: WebSocketServer;
  private clients = new Set<Client>();
  private byUser = new Map<string, Set<Client>>();
  private heartbeat?: NodeJS.Timeout;

  constructor(server: Server) {
    this.wss = new WebSocketServer({ server, path: WS_PATH, maxPayload: 16 * 1024, verifyClient: (info, cb) => this.verifyOrigin(info.req, cb) });
    this.wss.on('connection', (ws, req) => void this.onConnection(ws, req));
  }

  async start(): Promise<void> {
    await redisSub.subscribe(CHANNELS.ticks);
    await redisSub.psubscribe(CHANNELS.userPattern);
    redisSub.on('message', (channel, message) => {
      if (channel === CHANNELS.ticks) this.broadcastTicks(message);
    });
    redisSub.on('pmessage', (_pattern, channel, message) => {
      if (channel.startsWith('user:')) this.sendToUser(channel.slice(5), message);
    });

    this.heartbeat = setInterval(() => {
      for (const c of this.clients) {
        if (!c.alive) {
          c.ws.terminate();
          continue;
        }
        c.alive = false;
        c.ws.ping();
      }
    }, HEARTBEAT_MS);
    logger.info({ path: WS_PATH }, 'websocket gateway ready');
  }

  async stop(): Promise<void> {
    if (this.heartbeat) clearInterval(this.heartbeat);
    for (const c of this.clients) c.ws.close(1001, 'Server shutting down');
    await new Promise<void>((resolve) => this.wss.close(() => resolve()));
  }

  get connections(): number {
    return this.clients.size;
  }

  private verifyOrigin(req: IncomingMessage, cb: (ok: boolean, code?: number, msg?: string) => void): void {
    const origin = req.headers.origin;
    // Native mobile clients send no Origin. Browsers must come from an allowed origin.
    if (!origin || corsOrigins.length === 0 || corsOrigins.includes(origin)) return cb(true);
    cb(false, 403, 'Origin not allowed');
  }

  private async onConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
    const client: Client = { ws, userId: null, symbols: new Set(), alive: true, msgCount: 0, msgWindow: Date.now() };
    this.clients.add(client);
    ws.on('pong', () => (client.alive = true));
    ws.on('close', () => this.remove(client));
    ws.on('error', () => this.remove(client));
    ws.on('message', (raw) => void this.onMessage(client, raw.toString()));

    const url = new URL(req.url ?? '/', 'http://localhost');
    const token = url.searchParams.get('token');
    if (token) await this.authenticate(client, token);

    this.send(client, { type: 'welcome', data: { authenticated: Boolean(client.userId), path: WS_PATH } });
  }

  private remove(client: Client): void {
    this.clients.delete(client);
    if (client.authTimer) clearTimeout(client.authTimer);
    if (client.userId) {
      const set = this.byUser.get(client.userId);
      set?.delete(client);
      if (set && set.size === 0) this.byUser.delete(client.userId);
    }
  }

  private async authenticate(client: Client, token: string): Promise<boolean> {
    try {
      const claims = verifyAccessToken(token);
      if (await isAccessTokenRevoked(claims.sub, claims.pv)) throw new Error('revoked');
      if (client.userId && client.userId !== claims.sub) this.byUser.get(client.userId)?.delete(client);
      client.userId = claims.sub;
      if (!this.byUser.has(claims.sub)) this.byUser.set(claims.sub, new Set());
      this.byUser.get(claims.sub)!.add(client);
      // Drop private events when the token expires; the app re-sends {"action":"auth"} after refreshing.
      if (client.authTimer) clearTimeout(client.authTimer);
      client.authTimer = setTimeout(() => {
        this.byUser.get(claims.sub)?.delete(client);
        client.userId = null;
        this.send(client, { type: 'auth_expired' });
      }, Math.max(0, claims.exp * 1000 - Date.now()));
      return true;
    } catch {
      this.send(client, { type: 'error', data: { code: 'INVALID_TOKEN', message: 'Authentication failed' } });
      return false;
    }
  }

  private async onMessage(client: Client, raw: string): Promise<void> {
    const now = Date.now();
    if (now - client.msgWindow > 10_000) {
      client.msgWindow = now;
      client.msgCount = 0;
    }
    if (++client.msgCount > MAX_MSGS_PER_10S) {
      client.ws.close(1008, 'Rate limit exceeded');
      return;
    }

    let msg: { action?: string; symbols?: unknown; token?: unknown };
    try {
      msg = JSON.parse(raw);
    } catch {
      return this.send(client, { type: 'error', data: { code: 'BAD_MESSAGE', message: 'Invalid JSON' } });
    }

    switch (msg.action) {
      case 'auth': {
        if (typeof msg.token !== 'string') return this.send(client, { type: 'error', data: { code: 'BAD_MESSAGE', message: 'token required' } });
        const ok = await this.authenticate(client, msg.token);
        if (ok) this.send(client, { type: 'authenticated' });
        return;
      }
      case 'subscribe':
      case 'unsubscribe': {
        const symbols = Array.isArray(msg.symbols) ? msg.symbols.filter((s): s is string => typeof s === 'string' && /^[A-Za-z0-9.*]{1,16}$/.test(s)) : [];
        for (const s of symbols) {
          const sym = s.toUpperCase();
          if (msg.action === 'subscribe') {
            if (client.symbols.size >= MAX_SYMBOLS) break;
            client.symbols.add(sym);
          } else client.symbols.delete(sym);
        }
        return this.send(client, { type: 'subscribed', data: { symbols: [...client.symbols] } });
      }
      case 'ping':
        return this.send(client, { type: 'pong', data: { ts: now } });
      default:
        return this.send(client, { type: 'error', data: { code: 'UNKNOWN_ACTION', message: 'Use auth, subscribe, unsubscribe or ping' } });
    }
  }

  private send(client: Client, payload: unknown): void {
    if (client.ws.readyState === WebSocket.OPEN) client.ws.send(typeof payload === 'string' ? payload : JSON.stringify(payload));
  }

  private broadcastTicks(message: string): void {
    let parsed: { data: TickPayload[] };
    try {
      parsed = JSON.parse(message);
    } catch {
      return;
    }
    for (const c of this.clients) {
      if (c.symbols.size === 0) continue;
      const data = c.symbols.has('*') ? parsed.data : parsed.data.filter((t) => c.symbols.has(t.symbol));
      if (data.length) this.send(c, { type: 'tick', data });
    }
  }

  private sendToUser(userId: string, message: string): void {
    const set = this.byUser.get(userId);
    if (!set) return;
    for (const c of set) this.send(c, message);
  }
}
