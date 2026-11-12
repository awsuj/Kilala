export type Status = "Active" | "Suspended" | "Expired";
export type PrivilegeType = "Senior" | "PWD";
export type DisabilityNature = "PERMANENT" | "TEMPORARY_OR_PROGRESSIVE";
export type CardSystemType =
  | "LEGACY_3_YEAR"
  | "UPDATED_5_YEAR"
  | "UNIFIED_2026";

export type PwdDetails = {
  disabilityType: string;
  disabilityNature: DisabilityNature;
  cardSystemType?: CardSystemType; // permanent cards don't need it
};

export type HistoryAction =
  | "Added"
  | "Edited"
  | "Suspended"
  | "Reinstated"
  | "Renewed";

export type HistoryEvent = {
  at: string; // YYYY-MM-DD
  action: HistoryAction;
  note?: string;
};

export type CardRecord = {
  id: string; // card number
  firstName: string;
  middleName: string;
  lastName: string;
  birthdate: string;
  issuingLgu: string;
  issuingDate: string;
  type: PrivilegeType;
  pwd?: PwdDetails;
  expiry: string | null; // null = lifetime
  suspended: boolean;
  history: HistoryEvent[];
};

// The only fields admin can edit directly
export type EditableFields = Pick<
  CardRecord,
  "firstName" | "middleName" | "lastName" | "birthdate"
>;

export type NewRecordInput = {
  firstName: string;
  middleName: string;
  lastName: string;
  birthdate: string;
  cardNumber: string;
  issuingLgu: string;
  issuingDate: string;
  privilegeType: PrivilegeType;
  pwd?: PwdDetails;
};
