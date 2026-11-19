import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam } from "@/lib/city";
import BusinessesTable, { type Business } from "./businesses-table";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

// Wired to GET /api/lgu/businesses. Accreditation toggle calls
// PATCH /api/lgu/businesses/:id/accreditation (see ./actions.ts).
export default async function BusinessesPage() {
  const lguParam = await getLguIdParam();

  // SUPERADMIN with no city picked — prompt to select one.
  if (lguParam === null) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Businesses</CardTitle>
          <CardDescription>
            Select a city from the top bar to view this page.
          </CardDescription>
        </CardHeader>
        <CardContent />
      </Card>
    );
  }

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

  return <BusinessesTable rows={rows} />;
}
