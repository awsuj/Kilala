"use server";

import { apiFetch, ApiError } from "@/lib/api";

export async function createLguAccount(input: {
  email: string;
  password: string;
  lgu_id: string;
  first_name: string;
  last_name: string;
  department: string;
  position?: string;
}): Promise<{ ok: true } | { ok: false; error: string }> {
  try {
    await apiFetch("/api/lgu-admins", {
      method: "POST",
      body: JSON.stringify(input),
    });
    return { ok: true };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof ApiError ? e.message : "Could not create the account.",
    };
  }
}
