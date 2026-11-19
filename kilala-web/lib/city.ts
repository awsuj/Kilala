"use server";

import { cookies } from "next/headers";
import { getCurrentUser } from "./session";

export const CITY_COOKIE = "kilala_city";

/**
 * Reads the selected city (LGU id) from the city cookie.
 * For use in server components / server actions.
 */
export async function getSelectedCity(): Promise<string | null> {
  const value = (await cookies()).get(CITY_COOKIE)?.value;
  return value ?? null;
}

/**
 * Server action — sets the kilala_city cookie to the chosen LGU id.
 * Not httpOnly since it's purely a UI preference.
 */
export async function setCity(lguId: string): Promise<void> {
  (await cookies()).set(CITY_COOKIE, lguId, {
    httpOnly: false,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  });
}

/**
 * Returns the `?lgu_id=<city>` query string suffix for SUPERADMIN callers,
 * or an empty string for LGU_ADMIN callers (their city is implicit server-side).
 *
 * Returns `null` when the caller is SUPERADMIN but has not selected a city yet
 * — the caller should render a "select a city" prompt and return early.
 */
export async function getLguIdParam(): Promise<string | null | ""> {
  const user = await getCurrentUser();
  if (user?.role !== "SUPERADMIN") return "";
  const city = await getSelectedCity();
  if (!city) return null; // signal: no city picked
  return `?lgu_id=${encodeURIComponent(city)}`;
}
