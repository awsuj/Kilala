import { cookies } from "next/headers";
import { AUTH_COOKIE, decodeToken, TokenPayload } from "./token";

/**
 * Reads the signed-in admin from the auth cookie, for use in server
 * components (dashboard, login redirect, root). Returns null if not signed in.
 */
export async function getCurrentUser(): Promise<TokenPayload | null> {
  const token = (await cookies()).get(AUTH_COOKIE)?.value;
  return decodeToken(token);
}
