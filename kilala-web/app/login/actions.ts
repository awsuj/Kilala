"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { AUTH_COOKIE, ALLOWED_ROLE } from "@/lib/token";

const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:5000";

export interface LoginState {
  error?: string;
  email?: string;
}

/**
 * Authenticates against the backend's POST /api/auth/login, then sets the JWT
 * in an httpOnly cookie and redirects to the dashboard. The web portal never
 * touches the DB directly — only the backend API.
 */
export async function loginAction(
  _prev: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const email = String(formData.get("email") || "").trim();
  const password = String(formData.get("password") || "");

  if (!email || !password) {
    return { error: "Please enter your email and password.", email };
  }

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      cache: "no-store",
    });
  } catch {
    return { error: "Cannot reach the server. Please try again shortly.", email };
  }

  const body = await res.json().catch(() => ({}) as Record<string, unknown>);

  if (!res.ok) {
    const err = (body as { error?: string }).error;
    return { error: err || "Invalid email or password", email };
  }

  const user = (body as { user?: { role?: string } }).user;
  // The LGU portal is administrators only — valid cardholder/business logins
  // are still rejected here.
  if (user?.role !== ALLOWED_ROLE) {
    return { error: "This portal is for LGU administrators only.", email };
  }

  const token = (body as { token?: string }).token ?? "";
  (await cookies()).set(AUTH_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 24 * 60 * 60, // 24h, matches backend token lifetime
    path: "/",
  });

  redirect("/dashboard");
}
