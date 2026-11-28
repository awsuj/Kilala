import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardAction,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import { apiFetch, ApiError } from "@/lib/api";
import { getLguIdParam } from "@/lib/city";
import ExportCsvButton from "./ExportCsvButton";
import VerificationLogCard, { type LogRow } from "./VerificationLogCard";

// Live discounts & sales — GET /api/lgu/discounts (aggregated from transactions)
interface DiscountsResponse {
  summary: { totalDiscounts: number; totalSales: number; discountedTxns: number };
  byBusiness: {
    business_name: string;
    branch_name: string | null;
    txns: number;
    sales: number;
    discounts: number;
  }[];
}

const peso = (n: number) =>
  `₱${n.toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export default async function ReportsPage() {
  const lguParam = await getLguIdParam();

  const [logsRes, discountsRes] = await Promise.allSettled([
    apiFetch<LogRow[]>(`/api/lgu/logs${lguParam}`),
    apiFetch<DiscountsResponse>(`/api/lgu/discounts${lguParam}`),
  ]);

  const logs = logsRes.status === "fulfilled" ? logsRes.value : [];
  const logsError =
    logsRes.status === "rejected"
      ? logsRes.reason instanceof ApiError
        ? logsRes.reason.message
        : "Could not reach the server."
      : null;

  const discounts = discountsRes.status === "fulfilled" ? discountsRes.value : null;
  const discountsError =
    discountsRes.status === "rejected"
      ? discountsRes.reason instanceof ApiError
        ? discountsRes.reason.message
        : "Could not reach the server."
      : null;

  const avgDiscountPct =
    discounts && discounts.summary.totalSales > 0
      ? `${((discounts.summary.totalDiscounts / discounts.summary.totalSales) * 100).toFixed(1)}%`
      : "—";

  // CSV rows for the discounts report — raw numbers so they're spreadsheet-friendly.
  const discountRows: (string | number)[][] = discounts
    ? discounts.byBusiness.map((b) => [
        b.business_name,
        b.branch_name || "",
        b.txns,
        b.sales,
        b.discounts,
      ])
    : [];

  const summaryCards = [
    { label: "Total Discounts Provided", value: discounts ? peso(discounts.summary.totalDiscounts) : "—", hint: "All-time, LGU-wide" },
    { label: "Total Sales Recorded", value: discounts ? peso(discounts.summary.totalSales) : "—", hint: "Original bill amounts" },
    { label: "Discounted Transactions", value: discounts ? discounts.summary.discountedTxns.toLocaleString() : "—", hint: "Bills recorded" },
    { label: "Avg. Discount Rate", value: avgDiscountPct, hint: "Discounts ÷ sales" },
  ];

  return (
    <div className="space-y-6">
      {/* Discounts & sales summary — live */}
      {discountsError ? (
        <Card className="p-5">
          <p className="text-sm text-destructive">
            Couldn&apos;t load discount totals: {discountsError}
          </p>
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {summaryCards.map((s) => (
            <Card key={s.label} className="gap-0 p-5">
              <p className="text-sm font-bold text-muted-foreground">{s.label}</p>
              <p className="mt-3 text-2xl font-extrabold tracking-tight text-foreground">
                {s.value}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">{s.hint}</p>
            </Card>
          ))}
        </div>
      )}

      {/* Discounts provided by business — live */}
      <Card>
        <CardHeader>
          <CardTitle>Discounts provided by business</CardTitle>
          <CardDescription>
            Total discounts each merchant gave on PWD &amp; Senior sales
          </CardDescription>
          <CardAction className="flex items-center gap-2">
            <Badge variant="outline">All-time</Badge>
            <ExportCsvButton
              filename="kilala-discounts-by-business.csv"
              headers={[
                "Business",
                "Branch",
                "Transactions",
                "Sales",
                "Discounts given",
              ]}
              rows={discountRows}
            />
          </CardAction>
        </CardHeader>
        <CardContent>
          {discountsError ? (
            <p className="py-8 text-center text-sm text-destructive">
              Couldn&apos;t load this report: {discountsError}
            </p>
          ) : !discounts || discounts.byBusiness.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              No discounted transactions recorded yet.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Business</TableHead>
                  <TableHead>Branch</TableHead>
                  <TableHead className="text-right">Transactions</TableHead>
                  <TableHead className="text-right">Sales</TableHead>
                  <TableHead className="text-right">Discounts given</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {discounts.byBusiness.map((b, i) => (
                  <TableRow key={`${b.business_name}-${i}`}>
                    <TableCell className="font-bold text-foreground">{b.business_name}</TableCell>
                    <TableCell className="text-muted-foreground">{b.branch_name || "—"}</TableCell>
                    <TableCell className="text-right font-mono">{b.txns.toLocaleString()}</TableCell>
                    <TableCell className="text-right font-mono">{peso(b.sales)}</TableCell>
                    <TableCell className="text-right font-mono font-bold text-foreground">{peso(b.discounts)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Verification audit log — live, with filters + filtered export */}
      <VerificationLogCard logs={logs} error={logsError} />
    </div>
  );
}
