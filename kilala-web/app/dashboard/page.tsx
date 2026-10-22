import { UserPlus, Store, Flag, FileCheck } from "lucide-react";
import StatCard from "../components/StatCard";

const stats = [
  { label: "Registered Cardholders", value: "12,480" },
  { label: "Businesses", value: "356" },
  { label: "Pending Applications", value: "42" },
  { label: "Flagged Records", value: "7" },
];

const registrations = [
  { month: "Jan", count: 820 },
  { month: "Feb", count: 940 },
  { month: "Mar", count: 1100 },
  { month: "Apr", count: 980 },
  { month: "May", count: 1350 },
  { month: "Jun", count: 1500 },
  { month: "Jul", count: 1720 },
];

const activity = [
  { icon: UserPlus, title: "New PWD card registered", time: "5 minutes ago" },
  {
    icon: Store,
    title: "Business verified: Tinuhog Ni Benny",
    time: "1 hour ago",
  },
  { icon: Flag, title: "Record flagged for review", time: "3 hours ago" },
  {
    icon: FileCheck,
    title: "Senior citizen application approved",
    time: "Yesterday",
  },
];

export default function DashboardPage() {
  const max = Math.max(...registrations.map((r) => r.count));

  return (
    <div className="space-y-6">
      {/* Stat cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((s) => (
          <StatCard key={s.label} label={s.label} value={s.value} />
        ))}
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        {/* Chart */}
        <section className="rounded-xl border border-hairline bg-white p-4 xl:col-span-2">
          <h2 className="text-base font-bold text-ink">
            Registrations over time
          </h2>

          <div className="mt-4 flex h-44 items-end gap-2">
            {registrations.map((r) => (
              <div
                key={r.month}
                className="flex h-full flex-1 flex-col items-center justify-end"
              >
                <span className="mb-1 text-sm font-bold text-ink">
                  {r.count}
                </span>
                <div
                  className="w-8 rounded-t-md bg-kilala-green"
                  style={{ height: `${(r.count / max) * 75}%` }}
                />
                <span className="mt-1 text-sm text-slate-ink">{r.month}</span>
              </div>
            ))}
          </div>
        </section>

        {/* Recent activity */}
        <section className="rounded-xl border border-hairline bg-white p-4">
          <h2 className="text-base font-bold text-ink">Recent Activity</h2>

          <ul className="mt-3 space-y-3">
            {activity.map((a) => {
              const Icon = a.icon;
              return (
                <li key={a.title} className="flex items-center gap-3">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-surface text-kilala-green">
                    <Icon className="h-5 w-5" aria-hidden="true" />
                  </div>
                  <div>
                    <p className="text-sm text-ink">{a.title}</p>
                    <p className="text-sm text-slate-ink">{a.time}</p>
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      </div>
    </div>
  );
}
