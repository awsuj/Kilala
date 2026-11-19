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
