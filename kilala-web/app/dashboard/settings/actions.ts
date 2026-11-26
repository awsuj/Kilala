"use server";

import { apiFetch, ApiError } from "@/lib/api";

type Result = { ok: true } | { ok: false; error: string };

export async function changePasswordAction(
  currentPassword: string,
  newPassword: string,
): Promise<Result> {
  try {
    await apiFetch("/api/lgu/me/password", {
      method: "PATCH",
      body: JSON.stringify({ currentPassword, newPassword }),
    });
    return { ok: true };
  } catch (err) {
    if (err instanceof ApiError) {
      if (err.status === 401)
        return {
          ok: false,
          error: "Your session has expired. Please sign in again.",
        };
      if (err.status >= 500)
        return {
          ok: false,
          error: "The server had a problem. Please try again.",
        };
      return { ok: false, error: err.message }; // e.g. "Current password is incorrect"
    }
    return { ok: false, error: "Could not reach the server." };
  }
}
