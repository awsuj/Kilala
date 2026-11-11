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
import { Field } from "./AddRecordDialog";
import type { CardRecord } from "./types";
import { formatName } from "./rules";

type Props = {
  record: CardRecord | null;
  onClose: () => void;
  onConfirm: (id: string, reason: string) => void;
};

export default function SuspendDialog({ record, onClose, onConfirm }: Props) {
  return (
    <Dialog
      open={record !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogContent className="sm:max-w-md">
        {record && (
          <SuspendForm
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

function SuspendForm({
  record,
  onClose,
  onConfirm,
}: {
  record: CardRecord;
  onClose: () => void;
  onConfirm: Props["onConfirm"];
}) {
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!reason.trim()) {
      setError("Please enter a reason.");
      return;
    }
    onConfirm(record.id, reason.trim());
    onClose();
  };

  return (
    <>
      <DialogHeader>
        <DialogTitle>
          <b>Suspend card?</b>
        </DialogTitle>
        <DialogDescription>
          {formatName(record)} will not be recognized by businesses until the
          card is reinstated.
        </DialogDescription>
      </DialogHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        <Field id="suspendReason" label="Reason*" error={error}>
          <Input
            id="suspendReason"
            placeholder="e.g. Reported lost card"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            aria-invalid={!!error}
          />
        </Field>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="destructive">
            Suspend card
          </Button>
        </DialogFooter>
      </form>
    </>
  );
}
