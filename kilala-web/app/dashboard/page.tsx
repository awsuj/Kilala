import { getCurrentUser } from "@/lib/session";
import { logoutAction } from "./actions";

// Placeholder for the next milestone (feat/web-lgu/dashboard). Middleware
// already guards this route; here we just confirm a role-gated login works.
export default async function DashboardPage() {
  const user = await getCurrentUser();

  return (
    <main className="mx-auto my-20 max-w-[640px] rounded-xl border border-hairline bg-white p-10 text-center">
      <h1 className="mt-0 text-[26px] font-bold text-kilala-green">You&apos;re signed in</h1>
      <p className="mt-3 text-slate-ink">
        Magandang araw po, <strong className="text-ink">{user?.email}</strong>
      </p>
      <p className="mt-1 font-mono text-sm text-slate-ink">role: {user?.role}</p>
      <p className="mt-4 text-slate-ink">
        The dashboard is coming in the next milestone
        (<span className="font-mono">feat/web-lgu/dashboard</span>).
      </p>
      <form action={logoutAction} className="mt-5">
        <button
          type="submit"
          className="mx-auto flex w-[200px] items-center justify-center rounded-lg bg-kilala-green px-4 py-3 font-bold text-white transition hover:bg-kilala-green-700"
        >
          Log out
        </button>
      </form>
    </main>
  );
}
