"use client";

import { usePathname, useRouter } from "next/navigation";
import { Bell } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { setCity } from "@/lib/city-actions";
import { ALL_CITIES } from "@/lib/city-constants";
import type { Lgu } from "@/lib/lgus";

const TITLES: Record<string, string> = {
  "/dashboard": "Dashboard",
  "/dashboard/records": "Records",
  "/dashboard/businesses": "Businesses",
  "/dashboard/reports": "Reports",
  "/dashboard/accounts": "Accounts",
};

function titleFor(pathname: string): string {
  const match = Object.keys(TITLES)
    .filter((href) =>
      href === "/dashboard" ? pathname === href : pathname.startsWith(href),
    )
    .sort((a, b) => b.length - a.length)[0];
  return match ? TITLES[match] : "Dashboard";
}

type Props = {
  role?: string | null;
  lgus?: Lgu[];
  selectedCity?: string | null;
};

export default function TopBar({ role, lgus = [], selectedCity }: Props) {
  const pathname = usePathname();
  const router = useRouter();

  const handleCityChange = async (lguId: string | null) => {
    if (!lguId) return;
    await setCity(lguId);
    router.refresh();
  };

  // base-ui's SelectValue renders the raw value (the LGU id) unless given an
  // items map to look up each value's label.
  const cityItems = {
    [ALL_CITIES]: "All cities",
    ...Object.fromEntries(lgus.map((lgu) => [lgu.id, lgu.municipality_name])),
  };

  return (
    <header className="flex items-center justify-between gap-4 px-6 pt-5 pb-3">
      <h1 className="text-2xl font-extrabold tracking-tight text-ink">
        {titleFor(pathname)}
      </h1>

      <div className="flex items-center gap-3">
        {role === "SUPERADMIN" && (
          <Select
            items={cityItems}
            value={selectedCity ?? ALL_CITIES}
            onValueChange={handleCityChange}
          >
            <SelectTrigger
              className="w-48"
              aria-label="City"
            >
              <SelectValue placeholder="All cities" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem key={ALL_CITIES} value={ALL_CITIES}>
                All cities
              </SelectItem>
              {lgus.map((lgu) => (
                <SelectItem key={lgu.id} value={lgu.id}>
                  {lgu.municipality_name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}

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
