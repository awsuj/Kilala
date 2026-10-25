"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LogOut, ChevronsLeft, ChevronsRight } from "lucide-react";
import Logo from "./Logo";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { logoutAction } from "@/app/dashboard/actions";

const navItems = [
  { label: "Dashboard", href: "/dashboard" },
  { label: "Applications", href: "/dashboard/applications" },
  { label: "Records", href: "/dashboard/records" },
  { label: "Reports", href: "/dashboard/reports" },
  { label: "Settings", href: "/dashboard/settings" },
];

export default function Sidebar({ adminEmail }: { adminEmail?: string | null }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const email = adminEmail || "admin@lgu.gov.ph";
  const initials = email.slice(0, 2).toUpperCase();

  // Retracted → just a floating button to bring the nav back.
  if (collapsed) {
    return (
      <div className="m-4 self-start">
        <button
          type="button"
          onClick={() => setCollapsed(false)}
          aria-label="Open navigation"
          className="flex h-11 w-11 items-center justify-center rounded-xl border border-border bg-card text-foreground shadow-sm transition-colors hover:bg-sidebar-accent"
        >
          <ChevronsRight className="h-5 w-5" aria-hidden="true" />
        </button>
      </div>
    );
  }

  return (
    <aside className="m-4 flex w-64 shrink-0 flex-col rounded-2xl border border-border bg-sidebar p-4 shadow-sm">
      {/* Logo + retract */}
      <div className="flex items-start justify-between px-2">
        <div>
          <Logo />
          <p className="mt-1 text-sm text-muted-foreground">LGU Portal</p>
        </div>
        <button
          type="button"
          onClick={() => setCollapsed(true)}
          aria-label="Retract navigation"
          className="-mr-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-foreground"
        >
          <ChevronsLeft className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>

      {/* Nav */}
      <nav className="mt-8 flex-1">
        <p className="px-3 pb-2 text-xs font-bold uppercase tracking-wider text-muted-foreground">
          Navigation
        </p>
        <ul className="space-y-1">
          {navItems.map((item) => {
            const isActive =
              item.href === "/dashboard"
                ? pathname === item.href
                : pathname.startsWith(item.href);

            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  aria-current={isActive ? "page" : undefined}
                  className={`block rounded-lg px-3.5 py-2.5 text-sm font-bold transition-colors ${
                    isActive
                      ? "bg-primary text-primary-foreground"
                      : "text-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
                  }`}
                >
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* Admin footer */}
      <div className="mt-6 rounded-xl border border-border bg-muted p-3">
        <div className="flex items-center gap-3">
          <Avatar className="h-9 w-9">
            <AvatarFallback className="bg-primary text-xs font-bold text-primary-foreground">
              {initials}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-foreground">LGU Admin</p>
            <p className="truncate text-xs text-muted-foreground">{email}</p>
          </div>
        </div>
        <form action={logoutAction} className="mt-3">
          <Button type="submit" variant="outline" className="w-full bg-card font-bold">
            <LogOut className="h-4 w-4" aria-hidden="true" />
            Log out
          </Button>
        </form>
      </div>
    </aside>
  );
}
