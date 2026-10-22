import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { ALLOWED_ROLE } from "@/lib/token";
import LoginForm from "./login-form";

export default async function LoginPage() {
  // Already signed in as an admin? Skip the form.
  const user = await getCurrentUser();
  if (user?.role === ALLOWED_ROLE) {
    redirect("/dashboard");
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <section className="w-full max-w-[420px] rounded-xl border border-hairline bg-white px-9 py-10 shadow-[0_12px_32px_rgba(17,32,27,0.06)]">
        <div className="mb-7">
          <div className="text-[32px] font-extrabold leading-none tracking-tight text-kilala-green">
            kilala
          </div>
          <p className="mt-3 text-[15px] text-slate-ink">
            LGU Portal. Sign in to manage records.
          </p>
        </div>

        <LoginForm />

        <div className="mt-5 text-center">
          <a href="#" className="text-sm text-slate-ink hover:text-kilala-green hover:underline">
            Forgot password?
          </a>
        </div>
      </section>
    </main>
  );
}
