import DashboardOverview, { type DashboardStats } from "./dashboard-overview";
import { apiFetch, ApiError } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

// Live aggregate stats from GET /api/lgu/dashboard. (pg COUNT() comes back as
// strings, so each field is coerced with Number.)
interface DashboardResponse {
  cardholderStats: {
    total_cardholders: string | number;
    active_pwd: string | number;
    active_senior: string | number;
    inactive_cards: string | number;
  };
  totalAccreditedBusinesses: number;
  scanStats: {
    total_scans: string | number;
    valid_scans: string | number;
    invalid_scans: string | number;
    scans_today: string | number;
  };
}

async function loadStats(): Promise<DashboardStats | { error: string }> {
  try {
    const d = await apiFetch<DashboardResponse>("/api/lgu/dashboard");
    return {
      registeredCardholders: Number(d.cardholderStats.total_cardholders),
      accreditedBusinesses: Number(d.totalAccreditedBusinesses),
      totalScans: Number(d.scanStats.total_scans),
      validScans: Number(d.scanStats.valid_scans),
      invalidScans: Number(d.scanStats.invalid_scans),
      scansToday: Number(d.scanStats.scans_today),
      activePwd: Number(d.cardholderStats.active_pwd),
      activeSenior: Number(d.cardholderStats.active_senior),
      inactiveCards: Number(d.cardholderStats.inactive_cards),
    };
  } catch (e) {
    return { error: e instanceof ApiError ? e.message : "Could not reach the server." };
  }
}

export default async function DashboardPage() {
  const stats = await loadStats();

  if ("error" in stats) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Dashboard</CardTitle>
          <CardDescription className="text-destructive">
            Couldn&apos;t load stats: {stats.error}
          </CardDescription>
        </CardHeader>
        <CardContent />
      </Card>
    );
  }

  return <DashboardOverview stats={stats} />;
}
