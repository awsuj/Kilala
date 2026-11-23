"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam, getSelectedCity, ALL_CITIES } from "@/lib/city";
import { getCurrentUser } from "@/lib/session";

export interface ToggleResult {
  error?: string;
}

export interface NewBusinessInput {
  businessName: string;
  issuingLgu: string;
  permitNo: string;
  tin: string;
}

/**
 * POST /api/lgu/businesses — register an accredited business (unclaimed; the
 * merchant later claims it from the app). The backend assigns the LGU from the
 * admin's session (LGU_ADMIN) or the selected city (SUPERADMIN), so — like
 * createCardholder — the form's Issuing LGU is not forwarded.
 */
export async function createBusiness(
  input: NewBusinessInput,
): Promise<{ error?: string }> {
  const body = JSON.stringify({
    business_name: input.businessName,
    business_permit_no: input.permitNo,
    tin_number: input.tin,
  });
  const fail = (e: unknown): { error: string } => ({
    error: e instanceof ApiError ? e.message : "Could not add the business.",
  });

  const user = await getCurrentUser();
  if (user?.role === "SUPERADMIN") {
    const city = await getSelectedCity();
    if (!city || city === ALL_CITIES) {
      return {
        error: "Select a city from the top bar before adding a business.",
      };
    }
    try {
      await apiFetch(`/api/lgu/businesses?lgu_id=${encodeURIComponent(city)}`, {
        method: "POST",
        body,
      });
    } catch (e) {
      return fail(e);
    }
    revalidatePath("/dashboard/businesses");
    return {};
  }

  const lguParam = await getLguIdParam();
  try {
    await apiFetch(`/api/lgu/businesses${lguParam}`, { method: "POST", body });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/dashboard/businesses");
  return {};
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
