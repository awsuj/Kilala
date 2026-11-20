import StatCard from "../components/StatCard";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

// Everything here is backed by GET /api/lgu/dashboard. Widgets that would need
// data the backend doesn't expose (monthly trend, per-barangay breakdown) were
// removed rather than mocked.
export interface DashboardStats {
  registeredCardholders: number;
  accreditedBusinesses: number;
  totalScans: number;
  validScans: number;
  invalidScans: number;
  scansToday: number;
  activePwd: number;
  activeSenior: number;
  inactiveCards: number;
}

const fmt = (n: number) => n.toLocaleString();

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-2.5">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="font-mono text-sm font-bold text-foreground">{value}</span>
    </div>
  );
}

export default function DashboardOverview({ stats }: { stats: DashboardStats }) {
  return (
    <div className="space-y-6">
      {/* Headline totals */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <StatCard label="Registered Cardholders" value={fmt(stats.registeredCardholders)} />
        <StatCard label="Accredited Businesses" value={fmt(stats.accreditedBusinesses)} />
        <StatCard label="Verifications" value={fmt(stats.totalScans)} />
      </div>

      {/* Verification + cardholder breakdowns — both live */}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader>
            <CardDescription>Verification results</CardDescription>
            <CardTitle className="text-4xl font-extrabold tracking-tight">
              {fmt(stats.totalScans)}
            </CardTitle>
          </CardHeader>
          <CardContent className="border-t border-border pt-2">
            <div className="divide-y divide-border">
              <Row label="Valid" value={fmt(stats.validScans)} />
              <Row label="Invalid" value={fmt(stats.invalidScans)} />
              <Row label="Today" value={fmt(stats.scansToday)} />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardDescription>Cardholder status</CardDescription>
            <CardTitle className="text-4xl font-extrabold tracking-tight">
              {fmt(stats.registeredCardholders)}
            </CardTitle>
          </CardHeader>
          <CardContent className="border-t border-border pt-2">
            <div className="divide-y divide-border">
              <Row label="Active · PWD" value={fmt(stats.activePwd)} />
              <Row label="Active · Senior" value={fmt(stats.activeSenior)} />
              <Row label="Inactive" value={fmt(stats.inactiveCards)} />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
