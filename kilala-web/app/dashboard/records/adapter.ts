import type {
  CardRecord,
  CardSystemType,
  DisabilityNature,
  NewRecordInput,
} from "./types";

// Shape returned by GET /api/lgu/cardholders (cardholder_profiles row + email).
// disability_nature / card_system_type are the additive columns — optional so
// the adapter works against the current backend before the migration lands.
export interface BackendCardholder {
  id: string;
  lgu_id_number: string;
  first_name: string;
  middle_name: string | null;
  last_name: string;
  date_of_birth: string;
  sex: string;
  address: string;
  privilege_type: "PWD" | "SENIOR_CITIZEN";
  disability_type: string | null;
  disability_nature?: string | null;
  card_system_type?: string | null;
  status: "ACTIVE" | "EXPIRED" | "REVOKED" | "SUSPENDED";
  issued_date: string;
  expiry_date: string | null;
}

/** Postgres DATE/TIMESTAMP can arrive as ISO; the UI wants bare YYYY-MM-DD. */
const dateOnly = (s: string | null): string => (s ? s.slice(0, 10) : "");

export function toCardRecord(
  row: BackendCardholder,
  lguName: string,
): CardRecord {
  const isPwd = row.privilege_type === "PWD";
  return {
    dbId: row.id,
    id: row.lgu_id_number,
    firstName: row.first_name,
    middleName: row.middle_name ?? "",
    lastName: row.last_name,
    birthdate: dateOnly(row.date_of_birth),
    issuingLgu: lguName || "—",
    issuingDate: dateOnly(row.issued_date),
    type: isPwd ? "PWD" : "Senior",
    pwd: isPwd
      ? {
          disabilityType: row.disability_type ?? "",
          // Prefer the stored nature; otherwise infer from whether it expires.
          disabilityNature:
            (row.disability_nature as DisabilityNature | undefined) ??
            (row.expiry_date ? "TEMPORARY_OR_PROGRESSIVE" : "PERMANENT"),
          cardSystemType:
            (row.card_system_type as CardSystemType | null) ?? undefined,
        }
      : undefined,
    expiry: row.expiry_date ? dateOnly(row.expiry_date) : null,
    // REVOKED has no distinct UI state yet; surface it as suspended.
    suspended: row.status === "SUSPENDED" || row.status === "REVOKED",
    // No cardholder audit table yet — seed a single "Added" event from issuance.
    history: [{ at: dateOnly(row.issued_date), action: "Added" }],
  };
}

/** Build the POST /api/lgu/cardholders body. Extra fields are ignored by the
 *  current backend and consumed once the additive migration ships. */
export function newRecordBody(input: NewRecordInput, expiry: string | null) {
  return {
    lgu_id_number: input.cardNumber,
    first_name: input.firstName,
    middle_name: input.middleName || null,
    last_name: input.lastName,
    date_of_birth: input.birthdate,
    sex: input.sex,
    address: input.address,
    privilege_type:
      input.privilegeType === "Senior" ? "SENIOR_CITIZEN" : "PWD",
    disability_type: input.pwd?.disabilityType ?? null,
    expiry_date: expiry,
    disability_nature: input.pwd?.disabilityNature ?? null,
    card_system_type: input.pwd?.cardSystemType ?? null,
    issued_date: input.issuingDate || null,
  };
}
