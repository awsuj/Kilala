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
import { Field } from "./AddRecordDialog";
import type { CardRecord, CardSystemType } from "./types";
import {
  CARD_SYSTEM_LABELS,
  computeExpiry,
  formatName,
  todayLocal,
} from "./rules";

type Props = {
  record: CardRecord | null;
  onClose: () => void;
  onConfirm: (
    id: string,
    issuingDate: string,
    cardSystem: CardSystemType,
  ) => void;
};

export default function RenewDialog({ record, onClose, onConfirm }: Props) {
  return (
    <Dialog
      open={record !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogContent className="sm:max-w-md">
        {record && (
          <RenewForm
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

function RenewForm({
  record,
  onClose,
  onConfirm,
}: {
  record: CardRecord;
  onClose: () => void;
  onConfirm: Props["onConfirm"];
}) {
  const today = todayLocal();
  const [issuingDate, setIssuingDate] = useState(today);
  const [cardSystem, setCardSystem] = useState<CardSystemType>("UNIFIED_2026");
  const [error, setError] = useState("");

  const newExpiry = computeExpiry(
    issuingDate,
    record.pwd?.disabilityNature ?? null,
    cardSystem,
  );

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!issuingDate) return setError("Issuing date is required.");
    if (issuingDate > today)
      return setError("Issuing date can't be in the future.");
    if (issuingDate < record.issuingDate)
      return setError("Can't be before the previous issuing date.");
    onConfirm(record.id, issuingDate, cardSystem);
    onClose();
  };

  return (
    <>
      <DialogHeader>
        <DialogTitle>
          <b>Renew card</b>
        </DialogTitle>
        <DialogDescription>
          {formatName(record)}&apos;s card expired on {record.expiry}. Renewing
          starts a new validity period.
        </DialogDescription>
      </DialogHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        <Field
          id="renewIssuingDate"
          label="New issuing date*"
          error={error}
          hint="As printed on the new card."
        >
          <Input
            id="renewIssuingDate"
            type="date"
            max={today}
            value={issuingDate}
            onChange={(e) => {
              setIssuingDate(e.target.value);
              setError("");
            }}
            aria-invalid={!!error}
          />
        </Field>

        <Field id="renewCardSystem" label="Card system*">
          <Select
            items={CARD_SYSTEM_LABELS}
            value={cardSystem}
            onValueChange={(v: string | null) => {
              if (v) setCardSystem(v as CardSystemType);
            }}
          >
            <SelectTrigger id="renewCardSystem" className="w-full">
              <SelectValue placeholder="Select the card system" />
            </SelectTrigger>
            <SelectContent>
              {(Object.keys(CARD_SYSTEM_LABELS) as CardSystemType[]).map(
                (k) => (
                  <SelectItem key={k} value={k}>
                    {CARD_SYSTEM_LABELS[k]}
                  </SelectItem>
                ),
              )}
            </SelectContent>
          </Select>
        </Field>

        {newExpiry && (
          <p className="rounded-md bg-muted px-3 py-2 text-sm text-foreground">
            New expiry: {newExpiry}
          </p>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit">Renew card</Button>
        </DialogFooter>
      </form>
    </>
  );
}
