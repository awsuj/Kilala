import Sidebar from "../components/Sidebar";
import TopBar from "../components/TopBar";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 bg-app-bg">
        <TopBar title="Dashboard" />

        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
