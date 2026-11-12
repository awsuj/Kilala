import type {
  CardRecord,
  CardSystemType,
  DisabilityNature,
  Status,
} from "./types";

export const NATURE_LABELS: Record<DisabilityNature, string> = {
  PERMANENT: "Permanent",
  TEMPORARY_OR_PROGRESSIVE: "Temporary or Progressive",
};

export const CARD_SYSTEM_LABELS: Record<CardSystemType, string> = {
  LEGACY_3_YEAR: "Legacy (3-Year)",
  UPDATED_5_YEAR: "Updated (5-Year)",
  UNIFIED_2026: "Unified (2026)",
};

export const DISABILITY_TYPES = [
  "VISUAL",
  "HEARING",
  "SPEECH LANGUAGE",
  "INTELLECTUAL",
  "PSYCHOSOCIAL",
  "ORTHOPEDIC",
  "LEARNING",
];

const YEARS_BY_CARD_SYSTEM: Record<CardSystemType, number> = {
  LEGACY_3_YEAR: 3,
  UPDATED_5_YEAR: 5,
  UNIFIED_2026: 5,
};

export const MIN_SENIOR_AGE = 60;
export const EXPIRING_SOON_DAYS = 30;

function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

// Returns the expiry date, or null if the card is lifetime (or not enough info yet).
export function computeExpiry(
  issuingDate: string,
  nature: DisabilityNature | null, // null for Seniors
  cardSystem?: CardSystemType | null,
): string | null {
  if (!issuingDate || !nature) return null;
  if (nature === "PERMANENT") return null;
  if (!cardSystem) return null;

  const years = YEARS_BY_CARD_SYSTEM[cardSystem];
  const [y, m, d] = issuingDate.split("-");
  const expiryYear = Number(y) + years;

  const day = m === "02" && d === "29" && !isLeapYear(expiryYear) ? "28" : d;

  return `${expiryYear}-${m}-${day}`;
}

// Format: YYYY-MM-DD
export function todayLocal(): string {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mm}-${dd}`;
}

export function daysUntil(date: string, from: string): number {
  const [y1, m1, d1] = from.split("-").map(Number);
  const [y2, m2, d2] = date.split("-").map(Number);
  return Math.round(
    (Date.UTC(y2, m2 - 1, d2) - Date.UTC(y1, m1 - 1, d1)) / 86400000,
  );
}

export function ageOn(birthdate: string, on: string): number {
  const [by, bm, bd] = birthdate.split("-").map(Number);
  const [oy, om, od] = on.split("-").map(Number);
  let age = oy - by;
  if (om < bm || (om === bm && od < bd)) age--;
  return age;
}

// Status is derived, never stored, so "Expired" can't go stale.
export function computeStatus(
  r: Pick<CardRecord, "expiry" | "suspended">,
  today: string,
): Status {
  if (r.suspended) return "Suspended";
  if (r.expiry && r.expiry < today) return "Expired";
  return "Active";
}

// Format: Last, First M.
export function formatName(
  r: Pick<CardRecord, "firstName" | "middleName" | "lastName">,
): string {
  const middle = r.middleName ? ` ${r.middleName[0].toUpperCase()}.` : "";
  return `${r.lastName}, ${r.firstName}${middle}`;
}

// 2026-11-20 -> Nov 20, 2026
export function formatDate(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}
