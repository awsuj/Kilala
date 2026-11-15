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

// Live audit log — GET /api/lgu/logs
interface LogRow {
  id: string;
  status_at_scan: string;
  is_valid: boolean;
  failure_reason: string | null;
  scanned_at: string;
  first_name: string;
  last_name: string;
  lgu_id_number: string;
  privilege_type: "PWD" | "SENIOR_CITIZEN";
  business_name: string;
  branch_name: string | null;
}

const typeLabel = (t: LogRow["privilege_type"]) =>
  t === "SENIOR_CITIZEN" ? "Senior" : "PWD";

/** "Today, 2:41 PM" / "Yesterday, 4:30 PM" / "Nov 3, 10:12 AM". */
function formatWhen(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  const sameDay = (a: Date, b: Date) => a.toDateString() === b.toDateString();
  if (sameDay(d, today)) return `Today, ${time}`;
  if (sameDay(d, yesterday)) return `Yesterday, ${time}`;
  const day = d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  return `${day}, ${time}`;
}

export default async function ReportsPage() {
  const [logsRes, discountsRes] = await Promise.allSettled([
    apiFetch<LogRow[]>("/api/lgu/logs"),
    apiFetch<DiscountsResponse>("/api/lgu/discounts"),
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
          <CardAction>
            <Badge variant="outline">All-time</Badge>
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

      {/* Verification audit log — live */}
      <Card>
        <CardHeader>
          <CardTitle>Verification audit log</CardTitle>
          <CardDescription>Recent QR scans across the LGU</CardDescription>
          <CardAction>
            <Badge variant="outline">Last 100</Badge>
          </CardAction>
        </CardHeader>
        <CardContent>
          {logsError ? (
            <p className="py-8 text-center text-sm text-destructive">
              Couldn&apos;t load audit log: {logsError}
            </p>
          ) : logs.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              No verification scans recorded yet.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>When</TableHead>
                  <TableHead>Cardholder</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Business</TableHead>
                  <TableHead>Result</TableHead>
                  <TableHead>Reason</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {logs.map((l) => (
                  <TableRow key={l.id}>
                    <TableCell className="whitespace-nowrap font-mono text-xs text-muted-foreground">
                      {formatWhen(l.scanned_at)}
                    </TableCell>
                    <TableCell>
                      <p className="font-bold text-foreground">
                        {l.last_name}, {l.first_name}
                      </p>
                      <p className="font-mono text-xs text-muted-foreground">{l.lgu_id_number}</p>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className="font-medium text-muted-foreground">
                        {typeLabel(l.privilege_type)}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-foreground">
                      {l.business_name}
                      {l.branch_name ? ` · ${l.branch_name}` : ""}
                    </TableCell>
                    <TableCell>
                      {l.is_valid ? (
                        <Badge variant="secondary">Valid</Badge>
                      ) : (
                        <Badge variant="outline" className="border-destructive/30 text-destructive">
                          Invalid
                        </Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {l.failure_reason || "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
