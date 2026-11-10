"use client";

import { useState } from "react";
import { Lock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Field } from "./AddRecordDialog";
import type { CardRecord, EditableFields } from "./types";
import { MIN_SENIOR_AGE, ageOn, todayLocal } from "./rules";

type Props = {
  record: CardRecord | null;
  onClose: () => void;
  onConfirm: (id: string, patch: EditableFields) => void;
};

type Errors = Partial<Record<keyof EditableFields, string>>;

export default function EditRecordDialog({
  record,
  onClose,
  onConfirm,
}: Props) {
  return (
    <Dialog
      open={record !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        {record && (
          <EditForm
            key={record.id}
            record={record}
            onClose={onClose}
            onConfirm={onConfirm}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}

function EditForm({
  record,
  onClose,
  onConfirm,
}: {
  record: CardRecord;
  onClose: () => void;
  onConfirm: Props["onConfirm"];
}) {
  const today = todayLocal();
  const [form, setForm] = useState<EditableFields>({
    firstName: record.firstName,
    middleName: record.middleName,
    lastName: record.lastName,
    birthdate: record.birthdate,
  });
  const [errors, setErrors] = useState<Errors>({});

  const setField = (field: keyof EditableFields, value: string) =>
    setForm((f) => ({ ...f, [field]: value }));

  const changed =
    form.firstName.trim() !== record.firstName ||
    form.middleName.trim() !== record.middleName ||
    form.lastName.trim() !== record.lastName ||
    form.birthdate !== record.birthdate;

  const validate = (): Errors => {
    const e: Errors = {};
    if (!form.firstName.trim()) e.firstName = "First name is required.";
    if (!form.lastName.trim()) e.lastName = "Last name is required.";

    if (!form.birthdate) e.birthdate = "Birthday is required.";
    else if (form.birthdate > today)
      e.birthdate = "Birthday can't be in the future.";
    else if (form.birthdate > record.issuingDate)
      e.birthdate = "Birthday can't be after the issuing date.";
    else if (
      record.type === "Senior" &&
      ageOn(form.birthdate, record.issuingDate) < MIN_SENIOR_AGE
    )
      e.birthdate = `Senior citizens must be at least ${MIN_SENIOR_AGE} on the issuing date.`;
    return e;
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const found = validate();
    if (Object.keys(found).length > 0) {
      setErrors(found);
      return;
    }
    onConfirm(record.id, {
      firstName: form.firstName.trim(),
      middleName: form.middleName.trim(),
      lastName: form.lastName.trim(),
      birthdate: form.birthdate,
    });
    onClose();
  };

  return (
    <>
      <DialogHeader>
        <DialogTitle>
          <b>Edit details</b>
        </DialogTitle>
        <DialogDescription>
          Fix mistakes in the cardholder&apos;s name or birthday.
        </DialogDescription>
      </DialogHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-3">
          <Field
            id="editFirstName"
            label="First name*"
            error={errors.firstName}
          >
            <Input
              id="editFirstName"
              value={form.firstName}
              onChange={(e) => setField("firstName", e.target.value)}
              aria-invalid={!!errors.firstName}
            />
          </Field>
          <Field id="editMiddleName" label="Middle name">
            <Input
              id="editMiddleName"
              placeholder="Optional"
              value={form.middleName}
              onChange={(e) => setField("middleName", e.target.value)}
            />
          </Field>
          <Field id="editLastName" label="Last name*" error={errors.lastName}>
            <Input
              id="editLastName"
              value={form.lastName}
              onChange={(e) => setField("lastName", e.target.value)}
              aria-invalid={!!errors.lastName}
            />
          </Field>
        </div>

        <Field id="editBirthdate" label="Birthday*" error={errors.birthdate}>
          <Input
            id="editBirthdate"
            type="date"
            max={today}
            value={form.birthdate}
            onChange={(e) => setField("birthdate", e.target.value)}
            aria-invalid={!!errors.birthdate}
          />
        </Field>

        <div className="space-y-2 rounded-md bg-muted p-3 text-sm">
          <p className="flex items-center gap-1.5 font-medium">
            <Lock className="size-3.5" /> Locked fields
          </p>
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-muted-foreground">
            <dt>Card number</dt>
            <dd className="font-mono text-foreground">{record.id}</dd>
            <dt>Type</dt>
            <dd className="text-foreground">{record.type}</dd>
            <dt>Issuing LGU</dt>
            <dd className="text-foreground">{record.issuingLgu}</dd>
            <dt>Issuing date</dt>
            <dd className="text-foreground">{record.issuingDate}</dd>
          </dl>
          <p className="text-xs text-muted-foreground">
            Card details change through renewal, not editing.
          </p>
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!changed}>
            Save changes
          </Button>
        </DialogFooter>
      </form>
    </>
  );
}
