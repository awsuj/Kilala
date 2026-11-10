"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";

export interface ToggleResult {
  error?: string;
}

/**
 * Flips a business's accreditation via PATCH /api/lgu/businesses/:id/accreditation.
 * Revalidates the page so the list reflects the backend's new state.
 */
export async function toggleAccreditation(
  id: string,
  isAccredited: boolean,
): Promise<ToggleResult> {
  try {
    await apiFetch(`/api/lgu/businesses/${id}/accreditation`, {
      method: "PATCH",
      body: JSON.stringify({ is_accredited: isAccredited }),
    });
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : "Could not update accreditation.";
    return { error: msg };
  }

  revalidatePath("/dashboard/businesses");
  return {};
}
