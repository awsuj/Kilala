import { cookies } from "next/headers";
import { AUTH_COOKIE } from "./token";

const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:5000";

/**
 * Server-side fetch against the Kilala backend, authenticated with the admin's
 * JWT from the httpOnly cookie. The portal never touches the DB directly — only
 * the backend API. Returns the parsed JSON body on 2xx, or throws ApiError.
 */
export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export async function apiFetch<T = unknown>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = (await cookies()).get(AUTH_COOKIE)?.value;

  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers || {}),
    },
    cache: "no-store",
  });

  const body = (await res.json().catch(() => ({}))) as unknown;

  if (!res.ok) {
    const err = (body as { error?: string }).error;
    throw new ApiError(err || `Request failed (${res.status})`, res.status);
  }

  return body as T;
}
