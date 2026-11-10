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

// ---------------------------------------------------------------------------
// Discount/sales figures still need a backend endpoint that aggregates the
// `transactions` table by lgu_id (e.g. GET /api/lgu/discounts) — not built yet,
// so these cards remain sample data. The audit log below is live.
// ---------------------------------------------------------------------------
const summary = [
  { label: "Total Discounts Provided", value: "₱1,284,560", hint: "Sample — endpoint pending" },
  { label: "Total Sales Recorded", value: "₱6,420,800", hint: "Sample — endpoint pending" },
  { label: "Discounts YTD (2026)", value: "₱980,230", hint: "Sample — endpoint pending" },
  { label: "Discounted Transactions", value: "12,840", hint: "Sample — endpoint pending" },
];

const byBusiness = [
  { name: "SM Supermarket", branch: "Makati Central", txns: "2,980", sales: "₱2,210,300", discounts: "₱442,060" },
  { name: "Mercury Drug", branch: "Makati Ave", txns: "3,210", sales: "₱1,840,500", discounts: "₱368,100" },
  { name: "Botika ng Barangay", branch: "Guadalupe", txns: "2,050", sales: "₱980,400", discounts: "₱196,080" },
  { name: "Tinuhog Ni Benny", branch: "Poblacion", txns: "1,140", sales: "₱320,800", discounts: "₱64,160" },
  { name: "Aling Nena Sari-Sari", branch: "Pembo", txns: "870", sales: "₱210,900", discounts: "₱42,180" },
];

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
  let logs: LogRow[] = [];
  let logsError: string | null = null;
  try {
    logs = await apiFetch<LogRow[]>("/api/lgu/logs");
  } catch (e) {
    logsError = e instanceof ApiError ? e.message : "Could not reach the server.";
  }

  return (
    <div className="space-y-6">
      {/* Discounts & sales summary */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {summary.map((s) => (
          <Card key={s.label} className="gap-0 p-5">
            <p className="text-sm font-bold text-muted-foreground">{s.label}</p>
            <p className="mt-3 text-2xl font-extrabold tracking-tight text-foreground">
              {s.value}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">{s.hint}</p>
          </Card>
        ))}
      </div>

      {/* Discounts provided by business */}
      <Card>
        <CardHeader>
          <CardTitle>Discounts provided by business</CardTitle>
          <CardDescription>
            Total discounts each merchant gave on PWD &amp; Senior sales
          </CardDescription>
          <CardAction>
            <Badge variant="outline">Sample data</Badge>
          </CardAction>
        </CardHeader>
        <CardContent>
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
              {byBusiness.map((b) => (
                <TableRow key={b.name}>
                  <TableCell className="font-bold text-foreground">{b.name}</TableCell>
                  <TableCell className="text-muted-foreground">{b.branch}</TableCell>
                  <TableCell className="text-right font-mono">{b.txns}</TableCell>
                  <TableCell className="text-right font-mono">{b.sales}</TableCell>
                  <TableCell className="text-right font-mono font-bold text-foreground">{b.discounts}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
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
