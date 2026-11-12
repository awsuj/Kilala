import { apiFetch, ApiError } from "@/lib/api";
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
  let rows: Business[];
  try {
    rows = await apiFetch<Business[]>("/api/lgu/businesses");
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
