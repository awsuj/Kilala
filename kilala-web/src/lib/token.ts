export interface TokenPayload {
  id?: string;
  role?: string;
  email?: string;
  exp?: number; // seconds since epoch
  [key: string]: unknown;
}

/**
 * Decodes (does NOT verify) a JWT payload. The web portal doesn't hold the
 * backend's JWT_SECRET, so it can't verify the signature — the backend remains
 * the authority for protected API calls. We only read the payload here to drive
 * UI/routing (greeting, role gate, expiry). Returns null if the token is
 * malformed or expired.
 */
export function decodeToken(token: string | undefined): TokenPayload | null {
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  try {
    const json = Buffer.from(parts[1], 'base64url').toString('utf8');
    const payload = JSON.parse(json) as TokenPayload;
    if (payload.exp && Date.now() >= payload.exp * 1000) return null; // expired
    return payload;
  } catch {
    return null;
  }
}
