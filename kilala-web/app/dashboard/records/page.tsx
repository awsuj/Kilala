"use client";

import { Suspense, useEffect, useState } from "react";
import { ChevronDown } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  ArrowDown,
  ArrowUp,
  Ban,
  CalendarX,
  Check,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  Clock,
  type LucideIcon,
} from "lucide-react";
import type {
  CardRecord,
  CardSystemType,
  EditableFields,
  HistoryAction,
  NewRecordInput,
  Status,
} from "./types";
import { seed } from "./mock-data";
import AddRecordDialog from "./AddRecordDialog";
import RenewDialog from "./RenewDialog";
import SuspendDialog from "./SuspendDialog";
import EditRecordDialog from "./EditRecordDialog";
import DetailsSheet from "./DetailsSheet";
import {
  EXPIRING_SOON_DAYS,
  computeExpiry,
  computeStatus,
  daysUntil,
  formatDate,
  formatName,
  todayLocal,
} from "./rules";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";

const PAGE_SIZE = 25; // set to 3 temporarily to test pagination with the mock data

type StatusFilter = "all" | "active" | "expiring" | "expired" | "suspended";
type TypeFilter = "all" | "PWD" | "Senior";
type SortKey = "status" | "name" | "expiry";
type SortDir = "asc" | "desc";

const STATUS_TABS: { value: StatusFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "active", label: "Active" },
  { value: "expiring", label: "Expiring soon" },
  { value: "expired", label: "Expired" },
  { value: "suspended", label: "Suspended" },
];
const STATUS_FILTERS = STATUS_TABS.map((t) => t.value);
const TYPE_FILTERS: readonly TypeFilter[] = ["all", "PWD", "Senior"];
const SORT_KEYS: readonly SortKey[] = ["status", "name", "expiry"];
const SORT_DIRS: readonly SortDir[] = ["asc", "desc"];

function pick<T extends string>(
  value: string | null,
  allowed: readonly T[],
  fallback: T,
): T {
  return allowed.includes(value as T) ? (value as T) : fallback;
}

// Search ignores capitals and accents, and IDs match with or without dashes
const norm = (s: string) =>
  s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
const squash = (s: string) => norm(s).replace(/[\s-]/g, "");

type RowView = { r: CardRecord; status: Status; expiringSoon: boolean };

// Needs-attention order: Expired, Expiring soon, Suspended, then everything else
const rank = (v: RowView) =>
  v.status === "Expired"
    ? 0
    : v.expiringSoon
      ? 1
      : v.status === "Suspended"
        ? 2
        : 3;

const byName = (a: RowView, b: RowView) =>
  a.r.lastName.localeCompare(b.r.lastName, "en", { sensitivity: "base" }) ||
  a.r.firstName.localeCompare(b.r.firstName, "en", { sensitivity: "base" });

function sortViews(list: RowView[], sort: SortKey, dir: SortDir): RowView[] {
  const sign = dir === "asc" ? 1 : -1;
  return [...list].sort((a, b) => {
    if (sort === "expiry") {
      const ea = a.r.expiry;
      const eb = b.r.expiry;
      if (ea === eb) return byName(a, b);
      if (ea === null) return 1; // lifetime cards always go last
      if (eb === null) return -1;
      return (ea < eb ? -1 : 1) * sign;
    }
    if (sort === "name") return byName(a, b) * sign;
    return (rank(a) - rank(b) || byName(a, b)) * sign;
  });
}

type BadgeKey = "active" | "expiringSoon" | "expired" | "suspended";

function getBadgeKey(status: Status, expiringSoon: boolean): BadgeKey {
  if (status === "Suspended") return "suspended";
  if (status === "Expired") return "expired";
  if (expiringSoon) return "expiringSoon";
  return "active";
}

const BADGES: Record<
  BadgeKey,
  { label: string; cls: string; Icon: LucideIcon }
> = {
  active: {
    label: "Active",
    cls: "bg-kilala-green/10 text-kilala-green",
    Icon: Check,
  },
  expiringSoon: {
    label: "Expiring soon",
    cls: "bg-[#F4B740]/20 text-[#7a4f00]",
    Icon: Clock,
  },
  expired: {
    label: "Expired",
    cls: "bg-[#B3261E]/10 text-[#B3261E]",
    Icon: CalendarX,
  },
  suspended: {
    label: "Suspended",
    cls: "bg-[#11201B]/10 text-[#4A5753]",
    Icon: Ban,
  },
};

function StatusBadge({
  status,
  expiringSoon,
}: {
  status: Status;
  expiringSoon: boolean;
}) {
  const { label, cls, Icon } = BADGES[getBadgeKey(status, expiringSoon)];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${cls}`}
    >
      <Icon className="size-3.5" aria-hidden="true" />
      {label}
    </span>
  );
}

function SortHeader({
  label,
  column,
  sort,
  dir,
  onSort,
}: {
  label: string;
  column: SortKey;
  sort: SortKey;
  dir: SortDir;
  onSort: (column: SortKey) => void;
}) {
  const active = sort === column;
  const Icon = !active ? ChevronsUpDown : dir === "asc" ? ArrowUp : ArrowDown;
  return (
    <button
      type="button"
      onClick={() => onSort(column)}
      className="inline-flex items-center gap-1 font-medium hover:text-foreground"
    >
      {label}
      <Icon
        className={`size-3.5 ${active ? "text-foreground" : "text-muted-foreground"}`}
      />
    </button>
  );
}

type DialogState = {
  kind: "suspend" | "renew" | "edit" | "details";
  id: string;
} | null;

type ToastState = {
  message: string;
  action?: { label: string; run: () => void };
} | null;

export default function RecordsPage() {
  // useSearchParams needs a Suspense boundary
  return (
    <Suspense fallback={null}>
      <RecordsView />
    </Suspense>
  );
}

function RecordsView() {
  const router = useRouter();
  const pathname = usePathname();
  const sp = useSearchParams();

  const [rows, setRows] = useState(seed);
  const [dialog, setDialog] = useState<DialogState>(null);
  const [toast, setToast] = useState<ToastState>(null);

  // Filters, sort and page start from the URL, then keep the URL up to date
  const [q, setQ] = useState(sp.get("q") ?? "");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>(
    pick(sp.get("status"), STATUS_FILTERS, "all"),
  );
  const [typeFilter, setTypeFilter] = useState<TypeFilter>(
    pick(sp.get("type"), TYPE_FILTERS, "all"),
  );
  const [sort, setSort] = useState<SortKey>(
    pick(sp.get("sort"), SORT_KEYS, "status"),
  );
  const [dir, setDir] = useState<SortDir>(
    pick(sp.get("dir"), SORT_DIRS, "asc"),
  );
  const [page, setPage] = useState(Math.max(1, Number(sp.get("page")) || 1));

  const today = todayLocal();

  const views: RowView[] = rows.map((r) => {
    const status = computeStatus(r, today);
    const expiringSoon =
      status === "Active" &&
      r.expiry !== null &&
      daysUntil(r.expiry, today) <= EXPIRING_SOON_DAYS;
    return { r, status, expiringSoon };
  });

  // search + type narrow the set, status tabs narrow it further
  const nq = norm(q.trim());
  const sq = squash(q.trim());
  const base = views.filter(({ r }) => {
    if (typeFilter !== "all" && r.type !== typeFilter) return false;
    if (!nq) return true;
    const haystack = norm(
      `${formatName(r)} ${r.firstName} ${r.middleName} ${r.lastName}`,
    );
    return haystack.includes(nq) || (sq !== "" && squash(r.id).includes(sq));
  });

  const counts: Record<StatusFilter, number> = {
    all: base.length,
    active: base.filter((v) => v.status === "Active").length,
    expiring: base.filter((v) => v.expiringSoon).length,
    expired: base.filter((v) => v.status === "Expired").length,
    suspended: base.filter((v) => v.status === "Suspended").length,
  };

  const matchesTab = (v: RowView) => {
    switch (statusFilter) {
      case "all":
        return true;
      case "active":
        return v.status === "Active";
      case "expiring":
        return v.expiringSoon;
      case "expired":
        return v.status === "Expired";
      case "suspended":
        return v.status === "Suspended";
    }
  };

  const list = sortViews(base.filter(matchesTab), sort, dir);

  const total = list.length;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const start = (safePage - 1) * PAGE_SIZE;
  const pageRows = list.slice(start, start + PAGE_SIZE);

  const hasFilters =
    q.trim() !== "" || statusFilter !== "all" || typeFilter !== "all";

  // keep the URL in sync (debounced so typing doesn't spam the router)
  useEffect(() => {
    const t = setTimeout(() => {
      const p = new URLSearchParams();
      if (q.trim()) p.set("q", q.trim());
      if (statusFilter !== "all") p.set("status", statusFilter);
      if (typeFilter !== "all") p.set("type", typeFilter);
      if (sort !== "status" || dir !== "asc") {
        p.set("sort", sort);
        p.set("dir", dir);
      }
      if (safePage > 1) p.set("page", String(safePage));
      const qs = p.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    }, 250);
    return () => clearTimeout(t);
  }, [q, statusFilter, typeFilter, sort, dir, safePage, pathname, router]);

  // toasts dismiss themselves
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 8000);
    return () => clearTimeout(t);
  }, [toast]);

  const changeQ = (v: string) => {
    setQ(v);
    setPage(1);
  };
  const changeStatus = (v: StatusFilter) => {
    setStatusFilter(v);
    setPage(1);
  };
  const changeType = (v: TypeFilter) => {
    setTypeFilter(v);
    setPage(1);
  };
  const clearFilters = () => {
    setQ("");
    setStatusFilter("all");
    setTypeFilter("all");
    setPage(1);
  };
  const onSort = (column: SortKey) => {
    if (sort === column) setDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSort(column);
      setDir("asc");
    }
    setPage(1);
  };
  const ariaSort = (column: SortKey) =>
    sort !== column ? "none" : dir === "asc" ? "ascending" : "descending";

  const target = dialog ? (rows.find((r) => r.id === dialog.id) ?? null) : null;
  const closeDialog = () => setDialog(null);
  const open = (kind: NonNullable<DialogState>["kind"], id: string) =>
    setDialog({ kind, id });

  // log an action in the record's history
  const withLog = (
    r: CardRecord,
    action: HistoryAction,
    note?: string,
  ): CardRecord => ({
    ...r,
    history: [...r.history, { at: today, action, note }],
  });

  // change one record, then show a toast with Undo
  const updateRecord = (
    id: string,
    fn: (r: CardRecord) => CardRecord,
    message: (updated: CardRecord) => string,
  ) => {
    const current = rows.find((r) => r.id === id);
    if (!current) return;
    const updated = fn(current);
    const before = rows;
    setRows((rs) => rs.map((r) => (r.id === id ? updated : r)));
    setToast({
      message: message(updated),
      action: { label: "Undo", run: () => setRows(before) },
    });
  };

  const handleAdd = (input: NewRecordInput) => {
    const expiry = computeExpiry(
      input.issuingDate,
      input.pwd?.disabilityNature ?? null,
      input.pwd?.cardSystemType ?? null,
    );
    const record: CardRecord = {
      id: input.cardNumber,
      firstName: input.firstName,
      middleName: input.middleName,
      lastName: input.lastName,
      birthdate: input.birthdate,
      issuingLgu: input.issuingLgu,
      issuingDate: input.issuingDate,
      type: input.privilegeType,
      pwd: input.pwd,
      expiry,
      suspended: false,
      history: [{ at: today, action: "Added" }],
    };
    setRows((rs) => [record, ...rs]);
    setToast({
      message: `${formatName(record)} added`,
      action: { label: "View", run: () => open("details", record.id) },
    });
  };

  const handleSuspend = (id: string, reason: string) =>
    updateRecord(
      id,
      (r) => withLog({ ...r, suspended: true }, "Suspended", reason),
      (u) => `${formatName(u)} suspended`,
    );

  const handleReinstate = (id: string) =>
    updateRecord(
      id,
      (r) => withLog({ ...r, suspended: false }, "Reinstated"),
      (u) => `${formatName(u)} reinstated`,
    );

  const handleRenew = (
    id: string,
    issuingDate: string,
    cardSystem: CardSystemType,
  ) =>
    updateRecord(
      id,
      (r) => {
        const expiry = computeExpiry(
          issuingDate,
          r.pwd?.disabilityNature ?? null,
          cardSystem,
        );
        return withLog(
          {
            ...r,
            issuingDate,
            expiry,
            pwd: r.pwd ? { ...r.pwd, cardSystemType: cardSystem } : r.pwd,
          },
          "Renewed",
          expiry ? `Valid until ${expiry}` : "Lifetime card",
        );
      },
      (u) =>
        u.expiry
          ? `${formatName(u)} renewed until ${formatDate(u.expiry)}`
          : `${formatName(u)} renewed`,
    );

  const handleEdit = (id: string, patch: EditableFields) =>
    updateRecord(
      id,
      (r) => {
        const parts: string[] = [];
        if (
          patch.firstName !== r.firstName ||
          patch.middleName !== r.middleName ||
          patch.lastName !== r.lastName
        )
          parts.push("name");
        if (patch.birthdate !== r.birthdate) parts.push("birthday");
        return withLog(
          { ...r, ...patch },
          "Edited",
          `Updated ${parts.join(" and ")}`,
        );
      },
      (u) => `Saved changes to ${formatName(u)}`,
    );

  const detailsRecord = dialog?.kind === "details" ? target : null;
  const detailsStatus = detailsRecord
    ? computeStatus(detailsRecord, today)
    : null;

  return (
    <div className="space-y-6">
      <Card>
        <CardContent className="space-y-4">
          {/* Status tabs with counts */}
          <div
            className="flex flex-wrap gap-2"
            role="group"
            aria-label="Filter by status"
          >
            {STATUS_TABS.map((t) => {
              const on = statusFilter === t.value;
              return (
                <button
                  key={t.value}
                  type="button"
                  aria-pressed={on}
                  onClick={() => changeStatus(t.value)}
                  className={`inline-flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${
                    on
                      ? "border-kilala-green bg-kilala-green text-white"
                      : "border-hairline bg-white text-foreground hover:bg-surface"
                  }`}
                >
                  {t.label}
                  <span
                    className={`text-xs ${on ? "text-white/80" : "text-muted-foreground"}`}
                  >
                    {counts[t.value]}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Toolbar */}
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex w-full max-w-lg items-center gap-3">
              <div className="w-full">
                <label htmlFor="record-search" className="sr-only">
                  Search by ID or name
                </label>
                <Input
                  id="record-search"
                  type="search"
                  placeholder="Search by ID or name..."
                  value={q}
                  onChange={(e) => changeQ(e.target.value)}
                />
              </div>
              <div className="relative shrink-0">
                <select
                  aria-label="Filter by type"
                  value={typeFilter}
                  onChange={(e) => changeType(e.target.value as TypeFilter)}
                  className="h-10 appearance-none rounded-full border border-hairline bg-white pl-4 pr-10 text-sm"
                >
                  <option value="all">All types</option>
                  <option value="PWD">PWD</option>
                  <option value="Senior">Senior</option>
                </select>
                <ChevronDown
                  aria-hidden="true"
                  className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
                />
              </div>
            </div>

            <AddRecordDialog
              existingIds={rows.map((r) => r.id)}
              onAdd={handleAdd}
            />
          </div>

          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ID No.</TableHead>
                <TableHead aria-sort={ariaSort("name")}>
                  <SortHeader
                    label="Name"
                    column="name"
                    sort={sort}
                    dir={dir}
                    onSort={onSort}
                  />
                </TableHead>
                <TableHead>Type</TableHead>
                <TableHead aria-sort={ariaSort("expiry")}>
                  <SortHeader
                    label="Expiry"
                    column="expiry"
                    sort={sort}
                    dir={dir}
                    onSort={onSort}
                  />
                </TableHead>
                <TableHead className="w-44" aria-sort={ariaSort("status")}>
                  <SortHeader
                    label="Status"
                    column="status"
                    sort={sort}
                    dir={dir}
                    onSort={onSort}
                  />
                </TableHead>
                <TableHead className="w-36 text-right">
                  <span className="sr-only">Actions</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {pageRows.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="py-10 text-center">
                    {hasFilters ? (
                      <div className="space-y-3">
                        <p className="text-muted-foreground">
                          No records match your filters.
                        </p>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={clearFilters}
                        >
                          Clear filters
                        </Button>
                      </div>
                    ) : (
                      <p className="text-muted-foreground">
                        No records yet. Use &quot;Add Record&quot; to register
                        the first cardholder.
                      </p>
                    )}
                  </TableCell>
                </TableRow>
              ) : (
                pageRows.map(({ r, status, expiringSoon }) => (
                  <TableRow
                    key={r.id}
                    className="cursor-pointer"
                    onClick={() => open("details", r.id)}
                  >
                    <TableCell className="font-mono text-sm">{r.id}</TableCell>
                    <TableCell>
                      <button
                        type="button"
                        className="text-left font-bold text-foreground hover:underline focus-visible:underline"
                      >
                        {formatName(r)}
                      </button>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {r.type}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {r.expiry ? formatDate(r.expiry) : "Lifetime"}
                    </TableCell>
                    <TableCell>
                      <StatusBadge
                        status={status}
                        expiringSoon={expiringSoon}
                      />
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-end gap-2">
                        {status === "Expired" && (
                          <Button
                            type="button"
                            size="sm"
                            onClick={(e) => {
                              e.stopPropagation();
                              open("renew", r.id);
                            }}
                          >
                            Renew
                          </Button>
                        )}
                        {status === "Suspended" && (
                          <Button
                            type="button"
                            size="sm"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleReinstate(r.id);
                            }}
                          >
                            Reinstate
                          </Button>
                        )}
                        <ChevronRight
                          aria-hidden
                          className="size-4 text-muted-foreground"
                        />
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>

          {/* Pagination */}
          <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-muted-foreground">
            <p>
              {total === 0
                ? "No records"
                : `Showing ${start + 1} to ${start + pageRows.length} of ${total}`}
            </p>
            {totalPages > 1 && (
              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={safePage <= 1}
                  onClick={() => setPage(safePage - 1)}
                >
                  <ChevronLeft className="size-4" /> Previous
                </Button>
                <span>
                  Page {safePage} of {totalPages}
                </span>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={safePage >= totalPages}
                  onClick={() => setPage(safePage + 1)}
                >
                  Next <ChevronRight className="size-4" />
                </Button>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <DetailsSheet
        record={detailsRecord}
        status={detailsStatus}
        onClose={closeDialog}
        onEdit={(id) => open("edit", id)}
        onRenew={(id) => open("renew", id)}
        onSuspend={(id) => open("suspend", id)}
        onReinstate={handleReinstate}
      />
      <SuspendDialog
        record={dialog?.kind === "suspend" ? target : null}
        onClose={closeDialog}
        onConfirm={handleSuspend}
      />
      <RenewDialog
        record={dialog?.kind === "renew" ? target : null}
        onClose={closeDialog}
        onConfirm={handleRenew}
      />
      <EditRecordDialog
        record={dialog?.kind === "edit" ? target : null}
        onClose={closeDialog}
        onConfirm={handleEdit}
      />

      {/* Toast */}
      {toast && (
        <div
          role="status"
          aria-live="polite"
          className="fixed bottom-6 left-1/2 z-[100] flex -translate-x-1/2 items-center gap-4 rounded-lg bg-[#11201B] px-4 py-3 text-sm text-white shadow-lg"
        >
          <span>{toast.message}</span>
          {toast.action && (
            <button
              type="button"
              className="font-semibold text-[#F4B740] hover:underline"
              onClick={() => {
                toast.action?.run();
                setToast(null);
              }}
            >
              {toast.action.label}
            </button>
          )}
        </div>
      )}
    </div>
  );
}
