import type { CardSystemType, DisabilityNature } from "./types";

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

function isLeapYear(year: number) {
  return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
}

// Returns the expiry date, or null if the card is lifetime (or not enough info yet).
export function computeExpiry(
  issuingDate: string,
  nature: DisabilityNature | null, // null for Seniors
  cardSystem?: CardSystemType | null,
): string | null {
  if (!issuingDate || !nature) return null;
  if (nature === "PERMANENT") return null; // lifetime, card system doesn't matter
  if (!cardSystem) return null;

  const years = YEARS_BY_CARD_SYSTEM[cardSystem];
  const [y, m, d] = issuingDate.split("-");
  const expiryYear = Number(y) + years;

  // Feb 29 issue dates: if the expiry year has no Feb 29, use Feb 28 (assumption only, clarify later)
  const day = m === "02" && d === "29" && !isLeapYear(expiryYear) ? "28" : d;

  return `${expiryYear}-${m}-${day}`;
}

// Today's date in the user's local timezone, as YYYY-MM-DD.
// (toISOString() uses UTC, which gives yesterday's date in the Philippine morning.)
export function todayLocal(): string {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mm}-${dd}`;
}
