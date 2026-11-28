import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam } from "@/lib/city";
import { getCurrentUser } from "@/lib/session";
import RecordsView from "./records-view";
import { toCardRecord, type BackendCardholder } from "./adapter";
import { getLgus, type Lgu } from "@/lib/lgus";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

interface DashboardAdmin {
  admin?: { lgu_name?: string } | null;
}

// Live records from GET /api/lgu/cardholders. The LGU name (for the card in the
// details sheet) comes from the dashboard endpoint's admin context.
export default async function RecordsPage() {
  const lguParam = await getLguIdParam();

  const [[listRes, dashRes, lgusRes], user] = await Promise.all([
    Promise.allSettled([
      apiFetch<BackendCardholder[]>(`/api/lgu/cardholders${lguParam}`),
      apiFetch<DashboardAdmin>(`/api/lgu/dashboard${lguParam}`),
      getLgus(),
    ]),
    getCurrentUser(),
  ]);

  if (listRes.status === "rejected") {
    const msg =
      listRes.reason instanceof ApiError
        ? listRes.reason.message
        : "Could not reach the server.";
    return (
      <Card>
        <CardHeader>
          <CardTitle>Records</CardTitle>
          <CardDescription className="text-destructive">
            Couldn&apos;t load records: {msg}
          </CardDescription>
        </CardHeader>
        <CardContent />
      </Card>
    );
  }

  // admin may be null for SUPERADMIN callers — guard it.
  const lguName =
    dashRes.status === "fulfilled"
      ? (dashRes.value.admin?.lgu_name ?? "")
      : "";
  const rows = listRes.value.map((r) => toCardRecord(r, lguName));
  const lgus: Lgu[] = lgusRes.status === "fulfilled" ? lgusRes.value : [];

  return (
    <RecordsView initialRows={rows} lgus={lgus} role={user?.role ?? null} />
  );
}
