"use client";

import { useActionState } from "react";
import { loginAction, LoginState } from "./actions";

const initialState: LoginState = {};

export default function LoginForm() {
  const [state, formAction, pending] = useActionState(loginAction, initialState);

  return (
    <form action={formAction} noValidate className="mt-6">
      {state.error && (
        <div
          role="alert"
          className="mb-5 rounded-lg border border-danger/25 bg-danger-bg px-4 py-3 text-sm text-danger"
        >
          {state.error}
        </div>
      )}

      <div className="mb-[18px]">
        <label htmlFor="email" className="mb-1.5 block text-sm font-bold text-ink">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          defaultValue={state.email ?? ""}
          required
          autoFocus
          className="w-full rounded-lg border border-hairline bg-app-bg px-3.5 py-3 text-base text-ink outline-none transition focus:border-kilala-green focus:bg-white focus:ring-[3px] focus:ring-kilala-green/15"
        />
      </div>

      <div className="mb-[18px]">
        <label htmlFor="password" className="mb-1.5 block text-sm font-bold text-ink">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="w-full rounded-lg border border-hairline bg-app-bg px-3.5 py-3 text-base text-ink outline-none transition focus:border-kilala-green focus:bg-white focus:ring-[3px] focus:ring-kilala-green/15"
        />
      </div>

      <button
        type="submit"
        disabled={pending}
        className="flex w-full items-center justify-center rounded-lg bg-kilala-green px-4 py-3.5 text-base font-bold text-white transition hover:bg-kilala-green-700 active:bg-kilala-green-800 disabled:opacity-60"
      >
        {pending ? "Signing in…" : "Log In"}
      </button>
    </form>
  );
}
