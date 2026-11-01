import type { Role } from '@prisma/client';

declare global {
  namespace Express {
    interface AuthUser {
      id: string;
      role: Role;
      unifiedId: string;
    }
    interface Request {
      user?: AuthUser;
      /** Parsed + validated input, populated by the validate() middleware. */
      valid: {
        body?: any;
        query?: any;
        params?: any;
      };
      id?: string;
    }
  }
}

export {};
