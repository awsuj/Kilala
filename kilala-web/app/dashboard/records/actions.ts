"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam } from "@/lib/city";
import { getCurrentUser } from "@/lib/session";
import { newRecordBody } from "./adapter";
import type { NewRecordInput } from "./types";

export interface ActionResult {
  error?: string;
}

const fail = (e: unknown, fallback: string): ActionResult => ({
  error: e instanceof ApiError ? e.message : fallback,
});

/** POST /api/lgu/cardholders — register a new cardholder. */
export async function createCardholder(
  input: NewRecordInput,
  expiry: string | null,
): Promise<ActionResult> {
  const user = await getCurrentUser();

  if (user?.role === "SUPERADMIN") {
    // The record's LGU is whatever the admin picked in the form's Issuing LGU
    // dropdown — the single source of truth, independent of the top-bar filter.
    const lguId = input.issuingLguId?.trim();
    if (!lguId) {
      return { error: "Select an issuing LGU before adding a record." };
    }
    // SUPERADMIN — POST with explicit lgu_id.
    try {
      await apiFetch(
        `/api/lgu/cardholders?lgu_id=${encodeURIComponent(lguId)}`,
        { method: "POST", body: JSON.stringify(newRecordBody(input, expiry)) },
      );
    } catch (e) {
      return fail(e, "Could not add the record.");
    }
    revalidatePath("/dashboard/records");
    return {};
  }

  // LGU_ADMIN — city is implicit server-side.
  const lguParam = await getLguIdParam();
  try {
    await apiFetch(`/api/lgu/cardholders${lguParam}`, {
      method: "POST",
      body: JSON.stringify(newRecordBody(input, expiry)),
    });
  } catch (e) {
    return fail(e, "Could not add the record.");
  }
  revalidatePath("/dashboard/records");
  return {};
}

/** PATCH status — SUSPENDED (suspend) or ACTIVE (reinstate). */
export async function setCardholderStatus(
  dbId: string,
  status: "SUSPENDED" | "ACTIVE",
): Promise<ActionResult> {
  try {
    await apiFetch(`/api/lgu/cardholders/${dbId}`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
  } catch (e) {
    return fail(e, "Could not update the card's status.");
  }
  revalidatePath("/dashboard/records");
  return {};
}

/** PATCH a renewed expiry; also flips status back to ACTIVE. */
export async function renewCardholder(
  dbId: string,
  expiry: string | null,
): Promise<ActionResult> {
  try {
    await apiFetch(`/api/lgu/cardholders/${dbId}`, {
      method: "PATCH",
      body: JSON.stringify({ status: "ACTIVE", expiry_date: expiry }),
    });
  } catch (e) {
    return fail(e, "Could not renew the card.");
  }
  revalidatePath("/dashboard/records");
  return {};
}
