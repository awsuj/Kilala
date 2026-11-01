"use client";

import { useState } from "react";
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
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type {
  CardSystemType,
  DisabilityNature,
  NewRecordInput,
  PrivilegeType,
} from "./types";
import {
  CARD_SYSTEM_LABELS,
  DISABILITY_TYPES,
  NATURE_LABELS,
  computeExpiry,
  todayLocal,
} from "./rules";

type FormState = {
  firstName: string;
  middleName: string; // Optional, some citizens don't have one
  lastName: string;
  birthday: string;
  cardNumber: string;
  issuingLgu: string;
  issuingDate: string;
  privilegeType: PrivilegeType | "";
  // PWD only
  disabilityType: string;
  disabilityNature: DisabilityNature | "";
  cardSystemType: CardSystemType | "";
};
type Errors = Partial<Record<keyof FormState, string>>;

const emptyForm: FormState = {
  firstName: "",
  middleName: "",
  lastName: "",
  birthday: "",
  cardNumber: "",
  issuingLgu: "",
  issuingDate: "",
  privilegeType: "",
  disabilityType: "",
  disabilityNature: "",
  cardSystemType: "",
};

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

type Props = {
  existingIds: string[];
  onAdd: (input: NewRecordInput) => void;
};

export default function AddRecordDialog({ existingIds, onAdd }: Props) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [errors, setErrors] = useState<Errors>({});

  const setField = (field: keyof FormState, value: string) =>
    setForm((f) => ({ ...f, [field]: value }));

  const today = todayLocal();

  // Card system only matters for non-permanent PWD cards (it decides the expiry)
  const needsCardSystem =
    form.privilegeType === "PWD" &&
    form.disabilityNature === "TEMPORARY_OR_PROGRESSIVE";

  const handleOpenChange = (next: boolean) => {
    setOpen(next);
    if (!next) {
      setForm(emptyForm);
      setErrors({});
    }
  };

  const validate = (): Errors => {
    const e: Errors = {};
    if (!form.firstName.trim()) e.firstName = "First name is required.";
    if (!form.lastName.trim()) e.lastName = "Last name is required.";

    if (!form.birthday) e.birthday = "Birthday is required.";
    else if (form.birthday > today)
      e.birthday = "Birthday can't be in the future.";

    const card = form.cardNumber.trim().toLowerCase();
    if (!card) e.cardNumber = "Card number is required.";
    else if (existingIds.some((id) => id.toLowerCase() === card))
      e.cardNumber = "This card number already exists.";

    if (!form.issuingLgu.trim()) e.issuingLgu = "Issuing LGU is required.";

    if (!form.issuingDate) e.issuingDate = "Issuing date is required.";
    else if (form.issuingDate > today)
      e.issuingDate = "Issuing date can't be in the future.";
    else if (form.birthday && form.issuingDate < form.birthday)
      e.issuingDate = "Issuing date can't be before the birthday.";

    if (!form.privilegeType) e.privilegeType = "Pick a privilege type.";

    if (form.privilegeType === "PWD") {
      if (!form.disabilityType) e.disabilityType = "Select a disability type.";
      if (!form.disabilityNature)
        e.disabilityNature = "Select the nature of the disability.";
      if (needsCardSystem && !form.cardSystemType)
        e.cardSystemType = "Select the card system shown on the card.";
    }
    return e;
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const found = validate();
    const { privilegeType, disabilityNature, cardSystemType } = form;
    if (Object.keys(found).length > 0 || privilegeType === "") {
      setErrors(found);
      return;
    }

    const base: NewRecordInput = {
      firstName: form.firstName.trim(),
      middleName: form.middleName.trim(),
      lastName: form.lastName.trim(),
      birthdate: form.birthday,
      cardNumber: form.cardNumber.trim(),
      issuingLgu: form.issuingLgu.trim(),
      issuingDate: form.issuingDate,
      privilegeType,
    };

    if (privilegeType === "PWD") {
      if (disabilityNature === "") return;
      onAdd({
        ...base,
        pwd: {
          disabilityType: form.disabilityType,
          disabilityNature,
          // Permanent cards are lifetime, so no card system is needed
          cardSystemType: cardSystemType === "" ? undefined : cardSystemType,
        },
      });
    } else {
      onAdd(base);
    }
    handleOpenChange(false);
  };

  // Live preview so the admin can see the result before submitting.
  const expiryPreview = (() => {
    if (!form.issuingDate || !form.privilegeType) return null;
    if (form.privilegeType === "Senior") return "Card does not expire.";
    if (form.disabilityNature === "PERMANENT") return "Card does not expire.";
    if (!form.disabilityNature || !form.cardSystemType) return null;
    const exp = computeExpiry(
      form.issuingDate,
      form.disabilityNature,
      form.cardSystemType,
    );
    return exp ? `Card valid until ${exp}.` : "Card does not expire.";
  })();

  return (
    <>
      <Button type="button" onClick={() => setOpen(true)}>
        + Add Record
      </Button>

      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              <b>Add Record</b>
            </DialogTitle>
            <DialogDescription>
              Register a new PWD or Senior Citizen cardholder.
            </DialogDescription>
          </DialogHeader>

          <form onSubmit={handleSubmit} noValidate className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-3">
              <Field
                id="firstName"
                label="First name*"
                error={errors.firstName}
              >
                <Input
                  id="firstName"
                  placeholder="Juan"
                  value={form.firstName}
                  onChange={(e) => setField("firstName", e.target.value)}
                  aria-invalid={!!errors.firstName}
                />
              </Field>
              <Field id="middleName" label="Middle name">
                <Input
                  id="middleName"
                  placeholder="Optional"
                  value={form.middleName}
                  onChange={(e) => setField("middleName", e.target.value)}
                />
              </Field>
              <Field id="lastName" label="Last name*" error={errors.lastName}>
                <Input
                  id="lastName"
                  placeholder="Dela Cruz"
                  value={form.lastName}
                  onChange={(e) => setField("lastName", e.target.value)}
                  aria-invalid={!!errors.lastName}
                />
              </Field>
            </div>

            <Field id="birthday" label="Birthday*" error={errors.birthday}>
              <Input
                id="birthday"
                type="date"
                max={today}
                value={form.birthday}
                onChange={(e) => setField("birthday", e.target.value)}
                aria-invalid={!!errors.birthday}
              />
            </Field>

            <Field
              id="cardNumber"
              label="Card number*"
              error={errors.cardNumber}
            >
              <Input
                id="cardNumber"
                placeholder="Card number as printed on the card"
                value={form.cardNumber}
                onChange={(e) => setField("cardNumber", e.target.value)}
                aria-invalid={!!errors.cardNumber}
              />
            </Field>

            <div className="grid gap-4 sm:grid-cols-2">
              <Field
                id="issuingLgu"
                label="Issuing LGU*"
                error={errors.issuingLgu}
              >
                <Input
                  id="issuingLgu"
                  placeholder="e.g. Quezon City"
                  value={form.issuingLgu}
                  onChange={(e) => setField("issuingLgu", e.target.value)}
                  aria-invalid={!!errors.issuingLgu}
                />
              </Field>
              <Field
                id="issuingDate"
                label="Issuing date*"
                error={errors.issuingDate}
                hint="As printed on the card."
              >
                <Input
                  id="issuingDate"
                  type="date"
                  max={today}
                  value={form.issuingDate}
                  onChange={(e) => setField("issuingDate", e.target.value)}
                  aria-invalid={!!errors.issuingDate}
                />
              </Field>
            </div>

            <fieldset className="space-y-2">
              <legend className="text-sm font-medium leading-none">
                Privilege type*
              </legend>
              <div className="mt-2 flex flex-wrap gap-x-8 gap-y-2">
                {[
                  { value: "PWD", label: "PWD" },
                  { value: "Senior", label: "Senior Citizen" },
                ].map((opt) => (
                  <label
                    key={opt.value}
                    className="flex cursor-pointer items-center gap-2 py-1 text-sm"
                  >
                    <input
                      type="radio"
                      name="privilegeType"
                      value={opt.value}
                      checked={form.privilegeType === opt.value}
                      onChange={() => setField("privilegeType", opt.value)}
                      aria-invalid={!!errors.privilegeType}
                      className="size-4 accent-kilala-green"
                    />
                    <span>{opt.label}</span>
                  </label>
                ))}
              </div>
              {errors.privilegeType && (
                <p role="alert" className="text-sm text-destructive">
                  {errors.privilegeType}
                </p>
              )}
            </fieldset>

            {form.privilegeType === "PWD" && (
              <>
                <Field
                  id="disabilityType"
                  label="Disability type*"
                  error={errors.disabilityType}
                >
                  <Select
                    value={form.disabilityType}
                    onValueChange={(v: string | null) =>
                      setField("disabilityType", v ?? "")
                    }
                  >
                    <SelectTrigger
                      id="disabilityType"
                      className="w-full"
                      aria-invalid={!!errors.disabilityType}
                    >
                      <SelectValue placeholder="Select a disability type" />
                    </SelectTrigger>
                    <SelectContent>
                      {DISABILITY_TYPES.map((t) => (
                        <SelectItem key={t} value={t}>
                          {t}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>

                <Field
                  id="disabilityNature"
                  label="Nature of disability*"
                  error={errors.disabilityNature}
                >
                  <Select
                    items={NATURE_LABELS}
                    value={form.disabilityNature}
                    onValueChange={(v: string | null) =>
                      setForm((f) => ({
                        ...f,
                        disabilityNature: (v ?? "") as DisabilityNature | "",
                        // permanent cards don't use a card system, so clear any old pick
                        cardSystemType:
                          v === "PERMANENT" ? "" : f.cardSystemType,
                      }))
                    }
                  >
                    <SelectTrigger
                      id="disabilityNature"
                      className="w-full"
                      aria-invalid={!!errors.disabilityNature}
                    >
                      <SelectValue placeholder="Select the nature" />
                    </SelectTrigger>
                    <SelectContent>
                      {(Object.keys(NATURE_LABELS) as DisabilityNature[]).map(
                        (k) => (
                          <SelectItem key={k} value={k}>
                            {NATURE_LABELS[k]}
                          </SelectItem>
                        ),
                      )}
                    </SelectContent>
                  </Select>
                </Field>

                {needsCardSystem && (
                  <Field
                    id="cardSystemType"
                    label="Card system*"
                    error={errors.cardSystemType}
                    hint="Check the version of the card being encoded."
                  >
                    <Select
                      items={CARD_SYSTEM_LABELS}
                      value={form.cardSystemType}
                      onValueChange={(v: string | null) =>
                        setField("cardSystemType", v ?? "")
                      }
                    >
                      <SelectTrigger
                        id="cardSystemType"
                        className="w-full"
                        aria-invalid={!!errors.cardSystemType}
                      >
                        <SelectValue placeholder="Select the card system" />
                      </SelectTrigger>
                      <SelectContent>
                        {(
                          Object.keys(CARD_SYSTEM_LABELS) as CardSystemType[]
                        ).map((k) => (
                          <SelectItem key={k} value={k}>
                            {CARD_SYSTEM_LABELS[k]}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </>
            )}

            {expiryPreview && (
              <p className="rounded-md bg-muted px-3 py-2 text-sm text-foreground">
                {expiryPreview}
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
              <Button type="submit">Add record</Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
