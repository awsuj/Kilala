/**
 * Shared city constants — no server-only imports, safe for client components.
 */

/** Cookie name used to persist the SUPERADMIN's selected city. */
export const CITY_COOKIE = "kilala_city";

/** Sentinel stored in the city cookie (and used as the picker value) when
 *  a SUPERADMIN wants the combined "all cities" view. */
export const ALL_CITIES = "ALL";
