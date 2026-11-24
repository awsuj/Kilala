import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam } from "@/lib/city";
import { getLgus, type Lgu } from "@/lib/lgus";
import BusinessesTable, { type Business } from "./businesses-table";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

// Wired to GET /api/lgu/businesses. Accreditation toggle calls
// PATCH /api/lgu/businesses/:id/accreditation; "Add Business" POSTs to
// /api/lgu/businesses (see ./actions.ts).
export default async function BusinessesPage() {
  const lguParam = await getLguIdParam();

  let rows: Business[];
  try {
    rows = await apiFetch<Business[]>(`/api/lgu/businesses${lguParam}`);
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : "Could not reach the server.";
    return (
      <Card>
        <CardHeader>
          <CardTitle>Businesses</CardTitle>
          <CardDescription className="text-destructive">
            Couldn&apos;t load businesses: {msg}
          </CardDescription>
        </CardHeader>
        <CardContent />
      </Card>
    );
  }

  let lgus: Lgu[] = [];
  try {
    lgus = await getLgus();
  } catch {
    // Non-fatal: the dropdown just renders empty if the LGU list is unavailable.
  }

  return <BusinessesTable rows={rows} lgus={lgus} />;
}
