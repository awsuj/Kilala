"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import PasswordInput from "@/app/components/PasswordInput";
import { changePasswordAction } from "./actions";

const MIN_PASSWORD_LENGTH = 8; // TODO: change later
type Message = { kind: "success" | "error"; text: string } | null;

function Field({
  id,
  label,
  error,
  hint,
  children,
}: {
  id: string;
  label: string;
  error?: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {hint && !error && (
        <p className="text-sm text-muted-foreground">{hint}</p>
      )}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}

function StatusMessage({ message }: { message: Message }) {
  if (!message) return null;
  return (
    <p
      role={message.kind === "error" ? "alert" : "status"}
      className={`text-sm ${
        message.kind === "error" ? "text-destructive" : "text-foreground"
      }`}
    >
      {message.text}
    </p>
  );
}

type PasswordErrors = Partial<Record<"current" | "next" | "confirm", string>>;

function PasswordCard({ email }: { email: string }) {
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [errors, setErrors] = useState<PasswordErrors>({});
  const [message, setMessage] = useState<Message>(null);
  const [pending, setPending] = useState(false);

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setMessage(null);

    const found: PasswordErrors = {};
    if (!currentPassword) found.current = "Enter your current password.";
    if (newPassword.length < MIN_PASSWORD_LENGTH)
      found.next = `Use at least ${MIN_PASSWORD_LENGTH} characters.`;
    else if (newPassword === currentPassword)
      found.next = "Your new password must be different.";
    if (confirm !== newPassword) found.confirm = "Passwords don't match.";
    setErrors(found);
    if (Object.keys(found).length > 0) return;

    setPending(true);
    try {
      const result = await changePasswordAction(currentPassword, newPassword);
      if (result.ok) {
        setCurrentPassword("");
        setNewPassword("");
        setConfirm("");
        setMessage({ kind: "success", text: "Password updated." });
      } else {
        setMessage({ kind: "error", text: result.error });
      }
    } catch {
      setMessage({
        kind: "error",
        text: "Something went wrong. Please try again.",
      });
    } finally {
      setPending(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Password</CardTitle>
        <CardDescription>
          Signed in as {email}. Enter your current password to choose a new one.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} noValidate className="space-y-4">
          <Field
            id="currentPassword"
            label="Current password"
            error={errors.current}
          >
            <PasswordInput
              id="currentPassword"
              autoComplete="current-password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              aria-invalid={!!errors.current}
            />
          </Field>
          <Field
            id="newPassword"
            label="New password"
            error={errors.next}
            hint={`At least ${MIN_PASSWORD_LENGTH} characters.`}
          >
            <PasswordInput
              id="newPassword"
              autoComplete="new-password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              aria-invalid={!!errors.next}
            />
          </Field>
          <Field
            id="confirmPassword"
            label="Confirm new password"
            error={errors.confirm}
          >
            <PasswordInput
              id="confirmPassword"
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              aria-invalid={!!errors.confirm}
            />
          </Field>
          <StatusMessage message={message} />
          <Button type="submit" disabled={pending}>
            {pending ? "Saving..." : "Change password"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

export default function SettingsForms({ email }: { email: string }) {
  return (
    <div className="max-w-2xl">
      <PasswordCard email={email} />
    </div>
  );
}
