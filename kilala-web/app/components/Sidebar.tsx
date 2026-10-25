"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  ClipboardList,
  FolderOpen,
  FileText,
  Settings,
  LogOut,
} from "lucide-react";
import { logoutAction } from "@/app/dashboard/actions";

const navItems = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  {
    label: "Applications",
    href: "/dashboard/applications",
    icon: ClipboardList,
  },
  { label: "Records", href: "/dashboard/records", icon: FolderOpen },
  { label: "Reports", href: "/dashboard/reports", icon: FileText },
  { label: "Settings", href: "/dashboard/settings", icon: Settings },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="sticky top-4 flex h-[calc(100vh-2rem)] w-60 shrink-0 flex-col self-start rounded-2xl bg-white p-4 shadow-sm">
      <div className="px-3 pt-2">
        <p className="text-xl font-bold tracking-wide text-kilala-green">
          KILALA
        </p>
        <p className="text-sm text-slate-ink">LGU Portal</p>
      </div>

      <nav aria-label="Main" className="mt-8">
        <ul className="space-y-1">
          {navItems.map((item) => {
            const isActive =
              item.href === "/dashboard"
                ? pathname === item.href
                : pathname.startsWith(item.href);
            const Icon = item.icon;

            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  aria-current={isActive ? "page" : undefined}
                  className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-kilala-green ${
                    isActive
                      ? "bg-kilala-green font-semibold text-white shadow-sm"
                      : "text-slate-ink hover:bg-app-bg hover:text-ink"
                  }`}
                >
                  <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="mt-auto rounded-xl bg-app-bg p-2">
        <p className="px-3 py-2 text-sm font-medium text-ink">Admin</p>
        <form action={logoutAction}>
          <button
            type="submit"
            className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-slate-ink hover:bg-white hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-kilala-green"
          >
            <LogOut className="h-4 w-4 shrink-0" aria-hidden="true" />
            Log out
          </button>
        </form>
      </div>
    </aside>
  );
}
