"use server";

import { cookies } from "next/headers";

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
