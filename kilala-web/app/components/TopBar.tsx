"use client";

import { usePathname } from "next/navigation";
import { Search, Bell } from "lucide-react";

const TITLES: Record<string, string> = {
  "/dashboard": "Dashboard",
  "/dashboard/applications": "Applications",
  "/dashboard/records": "Records",
  "/dashboard/reports": "Reports",
  "/dashboard/settings": "Settings",
};

function titleFor(pathname: string): string {
  const match = Object.keys(TITLES)
    .filter((href) =>
      href === "/dashboard" ? pathname === href : pathname.startsWith(href),
    )
    .sort((a, b) => b.length - a.length)[0];
  return match ? TITLES[match] : "Dashboard";
}

export default function TopBar() {
  const pathname = usePathname();

  return (
    <header className="flex items-center justify-between gap-4 px-6 pt-5 pb-3">
      <h1 className="text-2xl font-extrabold tracking-tight text-ink">
        {titleFor(pathname)}
      </h1>

      <div className="flex items-center gap-3">
        <div className="relative">
          <label htmlFor="search" className="sr-only">
            Search records
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-ink"
            aria-hidden="true"
          />
          <input
            id="search"
            type="search"
            placeholder="Search records..."
            className="kilala-input w-64 bg-white py-2.5 pl-9 text-sm"
          />
        </div>

        <button
          type="button"
          aria-label="Notifications"
          className="flex h-11 w-11 items-center justify-center rounded-xl border border-hairline bg-white text-slate-ink transition-colors hover:bg-surface"
        >
          <Bell className="h-5 w-5" aria-hidden="true" />
        </button>
      </div>
    </header>
  );
}
