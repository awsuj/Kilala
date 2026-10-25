import {
  Users,
  Store,
  ClipboardList,
  Flag,
  UserPlus,
  FileCheck,
} from "lucide-react";
import StatCard from "@/app/components/StatCard";
import RegistrationsChart from "@/app/components/RegistrationsChart";

const stats = [
  { label: "Registered Cardholders", value: "12,480", icon: Users },
  { label: "Businesses", value: "356", icon: Store },
  {
    label: "Pending Applications",
    value: "42",
    icon: ClipboardList,
    href: "/dashboard/applications",
    hint: "Review applications",
    featured: true,
  },
  {
    label: "Flagged Records",
    value: "7",
    icon: Flag,
    href: "/dashboard/records",
    hint: "Review flagged records",
  },
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
  return (
    <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <section
        aria-label="Summary"
        className="grid grid-cols-1 gap-6 sm:grid-cols-2 sm:grid-rows-2 xl:col-span-2"
      >
        {stats.map((s) => (
          <StatCard key={s.label} {...s} />
        ))}
      </section>

      <section className="rounded-2xl bg-surface p-5">
        <h2 className="text-base font-semibold text-ink">Recent Activity</h2>

        {activity.length === 0 ? (
          <p className="mt-4 text-sm text-slate-ink">No recent activity.</p>
        ) : (
          <ul
            tabIndex={0}
            aria-label="Recent activity list"
            className="mt-4 space-y-4 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-kilala-green xl:max-h-72 xl:overflow-y-auto xl:pr-2 xl:[scrollbar-width:thin]"
          >
            {activity.map((a) => {
              const Icon = a.icon;
              return (
                <li key={a.title} className="flex items-center gap-3">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white text-kilala-green">
                    <Icon className="h-4 w-4" aria-hidden="true" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-ink">{a.title}</p>
                    <p className="text-sm text-slate-ink">{a.time}</p>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <RegistrationsChart data={registrations} className="xl:col-span-3" />
    </div>
  );
}
