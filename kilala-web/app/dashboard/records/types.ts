export type Status = "Active" | "Expired" | "Suspended";
export type PrivilegeType = "Senior" | "PWD";
export type DisabilityNature = "PERMANENT" | "TEMPORARY_OR_PROGRESSIVE";
export type CardSystemType =
  | "LEGACY_3_YEAR"
  | "UPDATED_5_YEAR"
  | "UNIFIED_2026";

export type CardRecord = {
  id: string;
  name: string;
  type: PrivilegeType;
  expiry: string | null;
  status: Status;
};

export type PwdDetails = {
  disabilityType: string;
  disabilityNature: DisabilityNature;
  cardSystemType?: CardSystemType;
};

// Everything the Add Record form collects
export type NewRecordInput = {
  firstName: string;
  middleName: string;
  lastName: string;
  birthdate: string; // Format: YYYY-MM-DD
  cardNumber: string;
  issuingLgu: string;
  issuingDate: string; // YYYY-MM-DD format from the physical card
  privilegeType: PrivilegeType;
  pwd?: PwdDetails; // only present for PWD
};
