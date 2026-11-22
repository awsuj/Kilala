"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { Lgu } from "@/lib/lgus";
import { createLguAccount } from "./actions";

function Field({
  id,
  label,
  error,
  optional,
  hint,
  children,
}: {
  id: string;
  label: string;
  error?: string;
  optional?: boolean;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>
        {label}
        {optional && (
          <span className="font-normal text-muted-foreground"> (optional)</span>
        )}
      </Label>
      {children}
      {hint && !error && (
        <p className="text-xs text-muted-foreground">{hint}</p>
      )}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}

type FormState = {
  lgu_id: string;
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  department: string;
  position: string;
};

type Errors = Partial<Record<keyof FormState, string>>;

const emptyForm: FormState = {
  lgu_id: "",
  email: "",
  password: "",
  first_name: "",
  last_name: "",
  department: "",
  position: "",
};

type Props = {
  lgus: Lgu[];
};

export default function CreateAccountDialog({ lgus }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [errors, setErrors] = useState<Errors>({});
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const setField = (field: keyof FormState, value: string) =>
    setForm((f) => ({ ...f, [field]: value }));

  const handleOpenChange = (next: boolean) => {
    setOpen(next);
    if (!next) {
      setForm(emptyForm);
      setErrors({});
      setSubmitError(null);
      setSuccess(false);
    }
  };

  const validate = (): Errors => {
    const e: Errors = {};
    if (!form.lgu_id) e.lgu_id = "City is required.";
    if (!form.email.trim()) e.email = "Email is required.";
    if (!form.password) e.password = "Password is required.";
    if (!form.first_name.trim()) e.first_name = "First name is required.";
    if (!form.last_name.trim()) e.last_name = "Last name is required.";
    if (!form.department.trim()) e.department = "Department is required.";
    return e;
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const found = validate();
    if (Object.keys(found).length > 0) {
      setErrors(found);
      return;
    }

    setSubmitting(true);
    setSubmitError(null);

    const result = await createLguAccount({
      lgu_id: form.lgu_id,
      email: form.email.trim(),
      password: form.password,
      first_name: form.first_name.trim(),
      last_name: form.last_name.trim(),
      department: form.department.trim(),
      position: form.position.trim() || undefined,
    });

    setSubmitting(false);

    if (!result.ok) {
      setSubmitError(result.error);
      return;
    }

    setSuccess(true);
    // Re-fetch the server component so the new account shows in the table.
    router.refresh();
  };

  return (
    <>
      <Button type="button" onClick={() => setOpen(true)}>
        + Create LGU Account
      </Button>

      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              <b>Create LGU Account</b>
            </DialogTitle>
            <DialogDescription>
              Create a new LGU admin account for a municipality.
            </DialogDescription>
          </DialogHeader>

          {success ? (
            <div className="space-y-4">
              <p className="rounded-md bg-muted px-3 py-2 text-sm text-foreground">
                Account created successfully.
              </p>
              <DialogFooter>
                <Button type="button" onClick={() => handleOpenChange(false)}>
                  Close
                </Button>
              </DialogFooter>
            </div>
          ) : (
            <form onSubmit={handleSubmit} noValidate className="space-y-4">
              <Field id="lgu_id" label="City" error={errors.lgu_id}>
                <Select
                  items={Object.fromEntries(
                    lgus.map((lgu) => [lgu.id, lgu.municipality_name]),
                  )}
                  value={form.lgu_id}
                  onValueChange={(v: string | null) => setField("lgu_id", v ?? "")}
                >
                  <SelectTrigger
                    id="lgu_id"
                    className="w-full"
                    aria-invalid={!!errors.lgu_id}
                    aria-label="City"
                  >
                    <SelectValue placeholder="Select a city" />
                  </SelectTrigger>
                  <SelectContent>
                    {lgus.map((lgu) => (
                      <SelectItem key={lgu.id} value={lgu.id}>
                        {lgu.municipality_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>

              <Field id="email" label="Email" error={errors.email}>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@lgu.gov.ph"
                  value={form.email}
                  onChange={(e) => setField("email", e.target.value)}
                  aria-invalid={!!errors.email}
                />
              </Field>

              <Field id="password" label="Password" error={errors.password}>
                <Input
                  id="password"
                  type="password"
                  placeholder="Password"
                  value={form.password}
                  onChange={(e) => setField("password", e.target.value)}
                  aria-invalid={!!errors.password}
                />
              </Field>

              <div className="grid gap-4 sm:grid-cols-2">
                <Field
                  id="first_name"
                  label="First name"
                  error={errors.first_name}
                >
                  <Input
                    id="first_name"
                    placeholder="Juan"
                    value={form.first_name}
                    onChange={(e) => setField("first_name", e.target.value)}
                    aria-invalid={!!errors.first_name}
                  />
                </Field>
                <Field
                  id="last_name"
                  label="Last name"
                  error={errors.last_name}
                >
                  <Input
                    id="last_name"
                    placeholder="Dela Cruz"
                    value={form.last_name}
                    onChange={(e) => setField("last_name", e.target.value)}
                    aria-invalid={!!errors.last_name}
                  />
                </Field>
              </div>

              <Field
                id="department"
                label="Department"
                error={errors.department}
                hint="e.g. OSCA or PDAO"
              >
                <Input
                  id="department"
                  placeholder="e.g. OSCA or PDAO"
                  value={form.department}
                  onChange={(e) => setField("department", e.target.value)}
                  aria-invalid={!!errors.department}
                />
              </Field>

              <Field
                id="position"
                label="Position"
                optional
              >
                <Input
                  id="position"
                  placeholder="e.g. Director"
                  value={form.position}
                  onChange={(e) => setField("position", e.target.value)}
                />
              </Field>

              {submitError && (
                <p role="alert" className="text-sm text-destructive">
                  {submitError}
                </p>
              )}

              <DialogFooter>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => handleOpenChange(false)}
                >
                  Cancel
                </Button>
                <Button type="submit" disabled={submitting}>
                  {submitting ? "Creating..." : "Create account"}
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
