"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { logoutAction } from "@/app/dashboard/actions";

const navItems = [
  { label: "Dashboard", href: "/dashboard" },
  { label: "Applications", href: "/dashboard/applications" },
  { label: "Records", href: "/dashboard/records" },
  { label: "Reports", href: "/dashboard/reports" },
  { label: "Settings", href: "/dashboard/settings" },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex w-60 flex-col border-r border-hairline bg-surface p-4">
      {/* Logo block */}
      <div>
        <p className="text-2xl font-bold text-kilala-green">KILALA</p>
        <p className="text-sm text-slate-ink">LGU Portal</p>
      </div>

      {/* Nav */}
      <nav className="mt-8">
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
                  className={`block rounded-lg border-l-4 px-4 py-2 ${
                    isActive
                      ? "border-white bg-kilala-green font-bold text-white"
                      : "border-transparent text-ink hover:bg-white"
                  }`}
                >
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* Bottom: mt-auto pushes this down */}
      <div className="mt-auto">
        <p>Admin</p>
        <form action={logoutAction}>
          <button type="submit" className="text-kilala-green underline">
            Log out
          </button>
        </form>
      </div>
    </aside>
  );
}
