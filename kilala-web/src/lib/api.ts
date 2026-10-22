import { config } from '../config';

export interface LoginUser {
  id: string;
  email: string;
  role: string;
}

export type LoginResult =
  | { ok: true; token: string; user: LoginUser }
  | { ok: false; status: number; error: string };

/**
 * Calls the backend's POST /api/auth/login.
 * The web portal never touches the database directly — it only speaks to the
 * backend API (see backend/src/index.ts).
 */
export async function login(email: string, password: string): Promise<LoginResult> {
  let res: Response;
  try {
    res = await fetch(`${config.apiBaseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
  } catch {
    // Backend unreachable (not running, wrong API_BASE_URL, network error).
    return { ok: false, status: 503, error: 'Cannot reach the server. Please try again shortly.' };
  }

  let body: any = {};
  try {
    body = await res.json();
  } catch {
    /* non-JSON response — leave body empty */
  }

  if (!res.ok) {
    return {
      ok: false,
      status: res.status,
      error: body?.error || 'Invalid email or password',
    };
  }

  return { ok: true, token: body.token, user: body.user };
}
