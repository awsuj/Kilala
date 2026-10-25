import DashboardOverview from "./dashboard-overview";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardAction,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";

const barangays = [
  { name: "Poblacion", district: "District 1", registered: "2,540", active: "92%", type: "PWD", total: "2,336", trend: [4, 6, 5, 7, 8, 7, 9], up: true },
  { name: "Bel-Air", district: "District 1", registered: "1,980", active: "88%", type: "Senior", total: "1,742", trend: [8, 7, 7, 6, 5, 6, 5], up: false },
  { name: "San Lorenzo", district: "District 1", registered: "1,640", active: "90%", type: "PWD", total: "1,476", trend: [3, 4, 5, 5, 6, 7, 8], up: true },
  { name: "Guadalupe", district: "District 2", registered: "1,420", active: "85%", type: "Senior", total: "1,207", trend: [5, 6, 6, 7, 7, 8, 9], up: true },
  { name: "Pembo", district: "District 2", registered: "1,150", active: "81%", type: "PWD", total: "931", trend: [7, 6, 6, 5, 5, 4, 4], up: false },
];

function Sparkline({ data, up }: { data: number[]; up: boolean }) {
  const w = 76;
  const h = 26;
  const pad = 2;
  const max = Math.max(...data);
  const min = Math.min(...data);
  const pts = data
    .map((v, i) => {
      const x = pad + (i * (w - pad * 2)) / (data.length - 1);
      const y = pad + (h - pad * 2) * (1 - (v - min) / (max - min || 1));
      return `${x},${y}`;
    })
    .join(" ");
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} aria-hidden="true">
      <polyline points={pts} fill="none" stroke={up ? "var(--color-valid)" : "var(--color-danger)"} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      {/* Interactive stat cards + chart + highlight panel */}
      <DashboardOverview />

      {/* Data table + summary */}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader>
            <CardTitle>Cardholders by Barangay</CardTitle>
            <CardAction>
              <Badge variant="outline">All barangays</Badge>
            </CardAction>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Barangay</TableHead>
                  <TableHead>Registered</TableHead>
                  <TableHead>Active</TableHead>
                  <TableHead>Trend</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="text-right">Total</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {barangays.map((b) => (
                  <TableRow key={b.name}>
                    <TableCell>
                      <p className="font-bold text-foreground">{b.name}</p>
                      <p className="text-xs text-muted-foreground">{b.district}</p>
                    </TableCell>
                    <TableCell className="font-mono">{b.registered}</TableCell>
                    <TableCell className="font-mono">{b.active}</TableCell>
                    <TableCell>
                      <Sparkline data={b.trend} up={b.up} />
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className="font-medium text-muted-foreground">
                        {b.type}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right font-mono font-bold">{b.total}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        {/* Summary card */}
        <Card>
          <CardHeader>
            <CardTitle>This month</CardTitle>
            <CardDescription>Verification activity</CardDescription>
          </CardHeader>
          <CardContent className="space-y-5">
            <div>
              <p className="text-3xl font-extrabold tracking-tight text-foreground">98.2%</p>
              <p className="mt-1 text-sm text-muted-foreground">Valid scan rate</p>
            </div>
            <Separator />
            <div>
              <p className="text-3xl font-extrabold tracking-tight text-foreground">4,210</p>
              <p className="mt-1 text-sm text-muted-foreground">New registrations</p>
            </div>
            <Separator />
            <div>
              <p className="text-3xl font-extrabold tracking-tight text-primary">28%</p>
              <p className="mt-1 text-sm text-muted-foreground">Avg. discount applied</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
