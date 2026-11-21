import { apiFetch } from "./api";

export type Lgu = {
  id: string;
  lgu_code: string;
  municipality_name: string;
  province: string | null;
  region: string;
};

export async function getLgus(): Promise<Lgu[]> {
  return apiFetch<Lgu[]>("/api/lgus");
}

export type LguAdmin = {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  department: string;
  position: string | null;
  municipality_name: string;
  is_active: boolean;
  created_at: string;
};

export async function getLguAdmins(): Promise<LguAdmin[]> {
  return apiFetch<LguAdmin[]>("/api/lgu-admins");
}
