"use server";

import { cookies } from "next/headers";
import { CITY_COOKIE } from "./city";

/**
 * Server action — sets the kilala_city cookie to the chosen LGU id.
 * Lives in its own "use server" module so client components (TopBar) can import
 * it without pulling the server-only readers in ./city into the client bundle.
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
