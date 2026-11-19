import { cookies } from "next/headers";
import { getCurrentUser } from "./session";
import { CITY_COOKIE, ALL_CITIES } from "./city-constants";
export { CITY_COOKIE, ALL_CITIES } from "./city-constants";

/**
 * Reads the selected city (LGU id) from the city cookie.
 * Server-only (uses next/headers) — call from server components / actions.
 */
export async function getSelectedCity(): Promise<string | null> {
  const value = (await cookies()).get(CITY_COOKIE)?.value;
  return value ?? null;
}

/**
 * Returns the `?lgu_id=<city>` query string suffix for SUPERADMIN callers
 * when a specific city is selected, or an empty string otherwise.
 *
 * - LGU_ADMIN: always `""` (city is implicit server-side).
 * - SUPERADMIN with a real LGU id selected: `?lgu_id=<id>`.
 * - SUPERADMIN in all-cities mode (cookie is `"ALL"` or unset): `""`.
 *
 * Never returns `null` — all-cities is the default for SUPERADMIN.
 */
export async function getLguIdParam(): Promise<string> {
  const user = await getCurrentUser();
  if (user?.role !== "SUPERADMIN") return "";
  const city = await getSelectedCity();
  if (city && city !== ALL_CITIES) return `?lgu_id=${encodeURIComponent(city)}`;
  return "";
}
