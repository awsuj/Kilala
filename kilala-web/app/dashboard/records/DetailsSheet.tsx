"use client";

import { useState, type ReactNode } from "react";
import { Ban, Check, Clock, Copy, Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import type { CardRecord, Status } from "./types";
import {
  CARD_SYSTEM_LABELS,
  NATURE_LABELS,
  ageOn,
  daysUntil,
  formatDate,
  formatName,
  todayLocal,
} from "./rules";

type Props = {
  record: CardRecord | null;
  status: Status | null;
  onClose: () => void;
  onEdit: (id: string) => void;
  onRenew: (id: string) => void;
  onSuspend: (id: string) => void;
  onReinstate: (id: string) => void;
};

const titleCase = (s: string) =>
  s.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase());

// Every status has its own icon and word, never color alone (brand rule)
function StatusPill({ status }: { status: Status }) {
  const style = {
    Active: {
      cls: "bg-[#F4B740] text-[#11201B]",
      icon: <Check className="size-3.5" />,
    },
    Expired: {
      cls: "bg-white text-[#11201B]",
      icon: <Clock className="size-3.5" />,
    },
    Suspended: {
      cls: "bg-[#B3261E] text-white",
      icon: <Ban className="size-3.5" />,
    },
  }[status];

  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-bold ${style.cls}`}
    >
      {style.icon}
      {status}
    </span>
  );
}

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // clipboard can be blocked, nothing to do
    }
  };

  return (
    <button
      type="button"
      onClick={copy}
      aria-label="Copy card number"
      className="inline-flex shrink-0 items-center gap-1 rounded-md px-2 py-1 text-xs text-white/80 hover:bg-white/10 hover:text-white"
    >
      {copied ? (
        <>
          <Check className="size-3.5" /> Copied
        </>
      ) : (
        <>
          <Copy className="size-3.5" /> Copy
        </>
      )}
    </button>
  );
}

// Only shows when something needs attention
function Notice({
  record,
  status,
  today,
}: {
  record: CardRecord;
  status: Status;
  today: string;
}) {
  if (status === "Suspended") {
    const reason = [...record.history]
      .reverse()
      .find((e) => e.action === "Suspended")?.note;
    return (
      <div className="flex gap-3 rounded-lg border border-[#B3261E]/30 bg-[#B3261E]/5 p-3 text-sm">
        <Ban className="mt-0.5 size-4 shrink-0 text-[#B3261E]" />
        <div>
          <p className="font-medium text-foreground">This card is suspended</p>
          {reason && <p className="text-muted-foreground">Reason: {reason}</p>}
        </div>
      </div>
    );
  }

  if (!record.expiry) return null;
  const days = daysUntil(record.expiry, today);

  if (status === "Expired") {
    const ago = Math.abs(days);
    return (
      <div className="flex gap-3 rounded-lg border border-[#F4B740] bg-[#F4B740]/15 p-3 text-sm">
        <Clock className="mt-0.5 size-4 shrink-0 text-[#8a5a00]" />
        <div>
          <p className="font-medium text-foreground">
            Expired on {formatDate(record.expiry)}
          </p>
          <p className="text-muted-foreground">
            {ago} day{ago === 1 ? "" : "s"} ago. Renew to reactivate it.
          </p>
        </div>
      </div>
    );
  }

  if (days <= 30) {
    return (
      <div className="flex gap-3 rounded-lg border border-[#F4B740] bg-[#F4B740]/15 p-3 text-sm">
        <Clock className="mt-0.5 size-4 shrink-0 text-[#8a5a00]" />
        <p className="font-medium text-foreground">
          {days === 0
            ? "Expires today"
            : `Expires in ${days} day${days === 1 ? "" : "s"}`}
        </p>
      </div>
    );
  }

  return null;
}

function Rows({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {title}
      </h3>
      <dl className="mt-1 divide-y divide-hairline">{children}</dl>
    </section>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 py-2.5 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium text-foreground">{children}</dd>
    </div>
  );
}

export default function DetailsSheet({
  record,
  status,
  onClose,
  onEdit,
  onRenew,
  onSuspend,
  onReinstate,
}: Props) {
  return (
    <Sheet
      open={record !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <SheetContent className="flex w-full flex-col gap-0 p-0 sm:max-w-md">
        {record && status && (
          <DetailsBody
            key={record.id}
            record={record}
            status={status}
            onEdit={onEdit}
            onRenew={onRenew}
            onSuspend={onSuspend}
            onReinstate={onReinstate}
          />
        )}
      </SheetContent>
    </Sheet>
  );
}

function DetailsBody({
  record,
  status,
  onEdit,
  onRenew,
  onSuspend,
  onReinstate,
}: {
  record: CardRecord;
  status: Status;
  onEdit: Props["onEdit"];
  onRenew: Props["onRenew"];
  onSuspend: Props["onSuspend"];
  onReinstate: Props["onReinstate"];
}) {
  const [showAll, setShowAll] = useState(false);
  const today = todayLocal();

  const initials =
    `${record.firstName[0] ?? ""}${record.lastName[0] ?? ""}`.toUpperCase();
  const fullName = [record.firstName, record.middleName, record.lastName]
    .filter(Boolean)
    .join(" ");

  const events = [...record.history].reverse();
  const shownEvents = showAll ? events : events.slice(0, 3);

  return (
    <>
      <SheetHeader className="p-5 pr-12">
        <div className="flex items-center gap-3">
          <div
            aria-hidden
            className="flex size-11 shrink-0 items-center justify-center rounded-full bg-surface text-sm font-bold text-kilala-green"
          >
            {initials}
          </div>
          <div className="min-w-0">
            <SheetTitle className="truncate text-lg">
              <b>{formatName(record)}</b>
            </SheetTitle>
            <SheetDescription>
              {record.type === "PWD"
                ? "Person with Disability"
                : "Senior Citizen"}
            </SheetDescription>
          </div>
        </div>
      </SheetHeader>

      <div className="flex-1 space-y-6 overflow-y-auto px-5 pb-6">
        {/* The card, same look as the cardholder's mobile app */}
        <div className="space-y-4 rounded-2xl bg-kilala-green p-5 text-white">
          <div className="flex items-center justify-between gap-3">
            <p className="text-xs font-bold uppercase tracking-widest text-white/80">
              {record.type === "PWD"
                ? "PWD Privilege Card"
                : "Senior Citizen Card"}
            </p>
            <StatusPill status={status} />
          </div>
          <div className="flex items-center justify-between gap-2">
            <p className="font-mono text-lg font-semibold tracking-wide">
              {record.id}
            </p>
            <CopyButton value={record.id} />
          </div>
          <p className="text-sm text-white/80">
            {record.expiry
              ? `Valid until ${formatDate(record.expiry)}`
              : "Lifetime validity"}{" "}
            · {record.issuingLgu}
          </p>
        </div>

        <Notice record={record} status={status} today={today} />

        <Rows title="Personal">
          <Row label="Full name">{fullName}</Row>
          <Row label="Birthday">
            {formatDate(record.birthdate)} ({ageOn(record.birthdate, today)}{" "}
            yrs)
          </Row>
        </Rows>

        <Rows title="Card">
          <Row label="Issued on">{formatDate(record.issuingDate)}</Row>
          {record.type === "PWD" && (
            <Row label="Card system">
              {record.pwd?.cardSystemType
                ? CARD_SYSTEM_LABELS[record.pwd.cardSystemType]
                : "Not recorded"}
            </Row>
          )}
        </Rows>

        {record.type === "PWD" && record.pwd && (
          <Rows title="Disability">
            <Row label="Type">{titleCase(record.pwd.disabilityType)}</Row>
            <Row label="Nature">
              {NATURE_LABELS[record.pwd.disabilityNature]}
            </Row>
          </Rows>
        )}

        <section>
          <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            History
          </h3>
          <ol className="relative mt-3 space-y-4 border-l border-hairline pl-5">
            {shownEvents.map((ev, i) => (
              <li key={i} className="relative text-sm">
                <span
                  aria-hidden
                  className="absolute -left-[25px] top-1.5 size-2 rounded-full bg-kilala-green"
                />
                <p className="font-medium text-foreground">{ev.action}</p>
                {ev.note && <p className="text-muted-foreground">{ev.note}</p>}
                <p className="text-xs text-muted-foreground">
                  {formatDate(ev.at)}
                </p>
              </li>
            ))}
          </ol>
          {events.length > 3 && (
            <button
              type="button"
              onClick={() => setShowAll((s) => !s)}
              className="mt-3 text-sm font-medium text-kilala-green hover:underline"
            >
              {showAll ? "Show less" : `Show all (${events.length})`}
            </button>
          )}
        </section>
      </div>

      <SheetFooter className="flex-row gap-2 border-t border-hairline p-4">
        <Button
          type="button"
          variant="outline"
          className="flex-1"
          onClick={() => onEdit(record.id)}
        >
          <Pencil className="size-4" /> Edit details
        </Button>
        {status === "Expired" && (
          <Button
            type="button"
            className="flex-1"
            onClick={() => onRenew(record.id)}
          >
            Renew card
          </Button>
        )}
        {status === "Suspended" && (
          <Button
            type="button"
            className="flex-1"
            onClick={() => onReinstate(record.id)}
          >
            Reinstate
          </Button>
        )}
        {status === "Active" && (
          <Button
            type="button"
            variant="outline"
            className="flex-1 border-[#B3261E] text-[#B3261E] hover:bg-[#B3261E] hover:text-white"
            onClick={() => onSuspend(record.id)}
          >
            <Ban className="size-4" /> Suspend
          </Button>
        )}
      </SheetFooter>
    </>
  );
}
