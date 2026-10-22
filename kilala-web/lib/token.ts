export interface TokenPayload {
  id?: string;
  role?: string;
  email?: string;
  exp?: number; // seconds since epoch
  [key: string]: unknown;
}

export const AUTH_COOKIE = process.env.AUTH_COOKIE || "kilala_token";
export const ALLOWED_ROLE = "LGU_ADMIN";

/**
 * Decodes (does NOT verify) a JWT payload. The web portal doesn't hold the
 * backend's JWT_SECRET, so it can't verify the signature — the backend stays
 * the authority. We only read the payload to drive routing/UI (role gate,
 * expiry, greeting). Uses atob so it works in both the Edge middleware and
 * Node server components. Returns null if malformed or expired.
 */
export function decodeToken(token: string | undefined | null): TokenPayload | null {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const payload = JSON.parse(atob(padded)) as TokenPayload;
    if (payload.exp && Date.now() >= payload.exp * 1000) return null; // expired
    return payload;
  } catch {
    return null;
  }
}
