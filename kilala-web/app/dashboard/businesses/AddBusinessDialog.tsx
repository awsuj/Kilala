"use client";

import { useState } from "react";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { Lgu } from "@/lib/lgus";
import { Field } from "../records/AddRecordDialog";
import type { NewBusinessInput } from "./actions";

type FormState = {
  businessName: string;
  issuingLgu: string;
  permitNo: string;
  tin: string;
};
type Errors = Partial<Record<keyof FormState, string>>;

const emptyForm: FormState = {
  businessName: "",
  issuingLgu: "",
  permitNo: "",
  tin: "",
};

type Props = {
  lgus: Lgu[];
  existingPermits: string[];
  onAdd: (input: NewBusinessInput) => void;
};

export default function AddBusinessDialog({
  lgus,
  existingPermits,
  onAdd,
}: Props) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [errors, setErrors] = useState<Errors>({});

  const setField = (field: keyof FormState, value: string) =>
    setForm((f) => ({ ...f, [field]: value }));

  const handleOpenChange = (next: boolean) => {
    setOpen(next);
    if (!next) {
      setForm(emptyForm);
      setErrors({});
    }
  };

  const validate = (): Errors => {
    const e: Errors = {};
    if (!form.businessName.trim()) e.businessName = "Business name is required.";
    if (!form.issuingLgu.trim()) e.issuingLgu = "Issuing LGU is required.";

    const permit = form.permitNo.trim().toLowerCase();
    if (!permit) e.permitNo = "Business permit number is required.";
    else if (existingPermits.some((p) => p.toLowerCase() === permit))
      e.permitNo = "This business permit already exists.";

    if (!form.tin.trim()) e.tin = "TIN number is required.";
    return e;
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const found = validate();
    if (Object.keys(found).length > 0) {
      setErrors(found);
      return;
    }
    onAdd({
      businessName: form.businessName.trim(),
      issuingLgu: form.issuingLgu.trim(),
      permitNo: form.permitNo.trim(),
      tin: form.tin.trim(),
    });
    handleOpenChange(false);
  };

  return (
    <>
      <Button type="button" onClick={() => setOpen(true)}>
        + Add Business
      </Button>

      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              <b>Add Business</b>
            </DialogTitle>
            <DialogDescription>
              Register an LGU-accredited business. The merchant claims it from
              the app to create their login.
            </DialogDescription>
          </DialogHeader>

          <form onSubmit={handleSubmit} noValidate className="space-y-4">
            <Field
              id="businessName"
              label="Business name*"
              error={errors.businessName}
            >
              <Input
                id="businessName"
                placeholder="e.g., Mercury Drug"
                value={form.businessName}
                onChange={(e) => setField("businessName", e.target.value)}
                aria-invalid={!!errors.businessName}
              />
            </Field>

            <Field
              id="issuingLgu"
              label="Issuing LGU*"
              error={errors.issuingLgu}
            >
              <Select
                value={form.issuingLgu}
                onValueChange={(v: string | null) =>
                  setField("issuingLgu", v ?? "")
                }
              >
                <SelectTrigger
                  id="issuingLgu"
                  className="w-full"
                  aria-invalid={!!errors.issuingLgu}
                >
                  <SelectValue placeholder="Select a city" />
                </SelectTrigger>
                <SelectContent>
                  {lgus.map((lgu) => (
                    <SelectItem key={lgu.id} value={lgu.municipality_name}>
                      {lgu.municipality_name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field
              id="permitNo"
              label="Business permit number*"
              error={errors.permitNo}
            >
              <Input
                id="permitNo"
                placeholder="MKT-BP-2026-00001"
                value={form.permitNo}
                onChange={(e) => setField("permitNo", e.target.value)}
                aria-invalid={!!errors.permitNo}
              />
            </Field>

            <Field id="tin" label="TIN number*" error={errors.tin}>
              <Input
                id="tin"
                placeholder="000-123-456-000"
                value={form.tin}
                onChange={(e) => setField("tin", e.target.value)}
                aria-invalid={!!errors.tin}
              />
            </Field>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => handleOpenChange(false)}
              >
                Cancel
              </Button>
              <Button type="submit">Add Business</Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
