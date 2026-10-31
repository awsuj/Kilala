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

// ---------------------------------------------------------------------------
// Mock data.
//  - Discount/sales figures → need a new backend endpoint that aggregates the
//    `transactions` table by lgu_id (e.g. GET /api/lgu/discounts). Not built yet.
//  - Audit log → GET /api/lgu/logs (5.7), which already exists.
// ---------------------------------------------------------------------------
const summary = [
  { label: "Total Discounts Provided", value: "₱1,284,560", hint: "All-time, LGU-wide" },
  { label: "Total Sales Recorded", value: "₱6,420,800", hint: "Original bill amounts" },
  { label: "Discounts YTD (2026)", value: "₱980,230", hint: "Jan 1 – today" },
  { label: "Discounted Transactions", value: "12,840", hint: "Bills recorded" },
];

const byBusiness = [
  { name: "SM Supermarket", branch: "Makati Central", txns: "2,980", sales: "₱2,210,300", discounts: "₱442,060" },
  { name: "Mercury Drug", branch: "Makati Ave", txns: "3,210", sales: "₱1,840,500", discounts: "₱368,100" },
  { name: "Botika ng Barangay", branch: "Guadalupe", txns: "2,050", sales: "₱980,400", discounts: "₱196,080" },
  { name: "Tinuhog Ni Benny", branch: "Poblacion", txns: "1,140", sales: "₱320,800", discounts: "₱64,160" },
  { name: "Aling Nena Sari-Sari", branch: "Pembo", txns: "870", sales: "₱210,900", discounts: "₱42,180" },
];

const logs = [
  { when: "Today, 2:41 PM", name: "Juan Dela Cruz", lguId: "MKT-PWD-2026-00481", type: "PWD", business: "Mercury Drug", valid: true, reason: "—" },
  { when: "Today, 1:15 PM", name: "Maria Bautista", lguId: "MKT-OSCA-2026-08912", type: "Senior", business: "SM Supermarket", valid: true, reason: "—" },
  { when: "Today, 11:02 AM", name: "Pedro Santos", lguId: "MKT-PWD-2025-03120", type: "PWD", business: "Botika ng Barangay", valid: false, reason: "Card Expired" },
  { when: "Yesterday, 4:30 PM", name: "Ana Reyes", lguId: "MKT-OSCA-2024-00455", type: "Senior", business: "Tinuhog Ni Benny", valid: false, reason: "Revoked by LGU" },
  { when: "Yesterday, 10:12 AM", name: "Jose Cruz", lguId: "MKT-PWD-2026-00990", type: "PWD", business: "Mercury Drug", valid: true, reason: "—" },
];

export default function ReportsPage() {
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
            <Badge variant="outline">This year</Badge>
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

      {/* Verification audit log */}
      <Card>
        <CardHeader>
          <CardTitle>Verification audit log</CardTitle>
          <CardDescription>Recent QR scans across the LGU</CardDescription>
          <CardAction>
            <Badge variant="outline">Last 100</Badge>
          </CardAction>
        </CardHeader>
        <CardContent>
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
              {logs.map((l, i) => (
                <TableRow key={i}>
                  <TableCell className="whitespace-nowrap font-mono text-xs text-muted-foreground">{l.when}</TableCell>
                  <TableCell>
                    <p className="font-bold text-foreground">{l.name}</p>
                    <p className="font-mono text-xs text-muted-foreground">{l.lguId}</p>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className="font-medium text-muted-foreground">{l.type}</Badge>
                  </TableCell>
                  <TableCell className="text-foreground">{l.business}</TableCell>
                  <TableCell>
                    {l.valid ? (
                      <Badge variant="secondary">Valid</Badge>
                    ) : (
                      <Badge variant="outline" className="border-destructive/30 text-destructive">
                        Invalid
                      </Badge>
                    )}
                  </TableCell>
                  <TableCell className="text-muted-foreground">{l.reason}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
