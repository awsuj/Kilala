import { Request, Response, NextFunction } from 'express';
import { config } from '../config';
import { decodeToken, TokenPayload } from '../lib/token';

// Make the current admin available to views as `currentUser`.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Locals {
      currentUser?: TokenPayload | null;
    }
  }
}

/**
 * Populates res.locals.currentUser from the auth cookie on every request so
 * views can render the signed-in admin. Never blocks the request.
 */
export function loadUser(req: Request, res: Response, next: NextFunction): void {
  const token = req.cookies?.[config.authCookie];
  res.locals.currentUser = decodeToken(token);
  next();
}

/**
 * Guards portal pages (e.g. /dashboard). Redirects to /login when there's no
 * valid, unexpired LGU_ADMIN token.
 */
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const user = res.locals.currentUser;
  if (!user || user.role !== config.allowedRole) {
    res.redirect('/login');
    return;
  }
  next();
}
