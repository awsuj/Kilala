"use client";

import { useActionState } from "react";
import { loginAction, LoginState } from "./actions";

const initialState: LoginState = {};

export default function LoginForm() {
  const [state, formAction, pending] = useActionState(loginAction, initialState);

  return (
    <form action={formAction} noValidate className="mt-6">
      {state.error && (
        <div role="alert" className="kilala-alert-error mb-5">
          {state.error}
        </div>
      )}

      <div className="mb-[18px]">
        <label htmlFor="email" className="kilala-label">
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
          className="kilala-input"
        />
      </div>

      <div className="mb-[18px]">
        <label htmlFor="password" className="kilala-label">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="kilala-input"
        />
      </div>

      <button type="submit" disabled={pending} className="btn-primary w-full py-3.5">
        {pending ? "Signing in…" : "Log In"}
      </button>
    </form>
  );
}
