import { NextRequest, NextResponse } from "next/server";
import { AUTH_COOKIE, ALLOWED_ROLE, decodeToken } from "@/lib/token";

/**
 * Guards portal routes. Redirects to /login when there's no valid, unexpired
 * LGU_ADMIN token in the auth cookie.
 */
export function proxy(req: NextRequest) {
  const token = req.cookies.get(AUTH_COOKIE)?.value;
  const user = decodeToken(token);

  if (!user || user.role !== ALLOWED_ROLE) {
    const url = new URL("/login", req.url);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
