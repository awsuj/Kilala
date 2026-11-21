import Sidebar from "../components/Sidebar";
import TopBar from "../components/TopBar";
import { getCurrentUser } from "@/lib/session";
import { getLgus } from "@/lib/lgus";
import { getSelectedCity } from "@/lib/city";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await getCurrentUser();

  let lgus: Awaited<ReturnType<typeof getLgus>> = [];
  let selectedCity: string | null = null;

  if (user?.role === "SUPERADMIN") {
    [lgus, selectedCity] = await Promise.all([
      getLgus().catch(() => []),
      getSelectedCity(),
    ]);
  }

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar adminEmail={user?.email} role={user?.role} />
      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar role={user?.role} lgus={lgus} selectedCity={selectedCity} />
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  );
}
