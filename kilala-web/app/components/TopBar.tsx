"use client";

import { usePathname } from "next/navigation";
import { Search } from "lucide-react";

const titles: Record<string, string> = {
  "/dashboard": "Dashboard",
  "/dashboard/applications": "Applications",
  "/dashboard/records": "Records",
  "/dashboard/reports": "Reports",
  "/dashboard/settings": "Settings",
};

export default function TopBar() {
  const pathname = usePathname();
  const title = titles[pathname] ?? "Dashboard";

  return (
    <header className="flex h-16 items-center justify-between">
      <h1 className="text-2xl font-bold text-ink">{title}</h1>

      <div className="relative">
        <label htmlFor="search" className="sr-only">
          Search records
        </label>
        <Search
          className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-ink"
          aria-hidden="true"
        />
        <input
          id="search"
          type="search"
          placeholder="Search records"
          className="w-64 rounded-full bg-white py-2.5 pl-10 pr-4 text-sm text-ink shadow-sm placeholder:text-slate-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-kilala-green"
        />
      </div>
    </header>
  );
}
