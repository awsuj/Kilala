"use client";

import { useMemo, useState } from "react";
import { ChevronDown } from "lucide-react";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardAction,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import ExportCsvButton from "./ExportCsvButton";

// Live audit log — GET /api/lgu/logs
export interface LogRow {
  id: string;
  status_at_scan: string;
  is_valid: boolean;
  failure_reason: string | null;
  scanned_at: string;
  first_name: string;
  last_name: string;
  lgu_id_number: string;
  privilege_type: "PWD" | "SENIOR_CITIZEN";
  business_name: string;
  branch_name: string | null;
}

const typeLabel = (t: LogRow["privilege_type"]) =>
  t === "SENIOR_CITIZEN" ? "Senior" : "PWD";

/** "Today, 2:41 PM" / "Yesterday, 4:30 PM" / "Nov 3, 10:12 AM". */
function formatWhen(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const time = d.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  const sameDay = (a: Date, b: Date) => a.toDateString() === b.toDateString();
  if (sameDay(d, today)) return `Today, ${time}`;
  if (sameDay(d, yesterday)) return `Yesterday, ${time}`;
  const day = d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  return `${day}, ${time}`;
}

type TypeFilter = "all" | "PWD" | "SENIOR_CITIZEN";
type ResultFilter = "all" | "valid" | "invalid";

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <div className="relative shrink-0">
      <select
        aria-label={label}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-8 max-w-52 appearance-none truncate rounded-full border border-hairline bg-white pl-4 pr-9 text-sm"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown
        aria-hidden="true"
        className="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
      />
    </div>
  );
}

export default function VerificationLogCard({
  logs,
  error,
}: {
  logs: LogRow[];
  error: string | null;
}) {
  const [business, setBusiness] = useState("all");
  const [type, setType] = useState<TypeFilter>("all");
  const [result, setResult] = useState<ResultFilter>("all");

  const businesses = useMemo(
    () => Array.from(new Set(logs.map((l) => l.business_name))).sort(),
    [logs],
  );

  const filtered = logs.filter((l) => {
    if (business !== "all" && l.business_name !== business) return false;
    if (type !== "all" && l.privilege_type !== type) return false;
    if (result === "valid" && !l.is_valid) return false;
    if (result === "invalid" && l.is_valid) return false;
    return true;
  });

  const hasFilters = business !== "all" || type !== "all" || result !== "all";
  const clearFilters = () => {
    setBusiness("all");
    setType("all");
    setResult("all");
  };

  // Export exactly what's shown — raw timestamp so it's spreadsheet-friendly.
  const exportRows: (string | number)[][] = filtered.map((l) => [
    l.scanned_at,
    `${l.last_name}, ${l.first_name}`,
    l.lgu_id_number,
    typeLabel(l.privilege_type),
    l.business_name,
    l.branch_name || "",
    l.is_valid ? "Valid" : "Invalid",
    l.failure_reason || "",
  ]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Verification audit log</CardTitle>
        <CardDescription>Recent QR scans across the LGU</CardDescription>
        <CardAction className="flex items-center gap-2">
          <Badge variant="outline">Last 100</Badge>
          <ExportCsvButton
            filename="kilala-verification-log.csv"
            headers={[
              "Scanned at",
              "Cardholder",
              "ID No.",
              "Type",
              "Business",
              "Branch",
              "Result",
              "Reason",
            ]}
            rows={exportRows}
          />
        </CardAction>
      </CardHeader>
      <CardContent>
        {error ? (
          <p className="py-8 text-center text-sm text-destructive">
            Couldn&apos;t load audit log: {error}
          </p>
        ) : logs.length === 0 ? (
          <p className="py-8 text-center text-sm text-muted-foreground">
            No verification scans recorded yet.
          </p>
        ) : (
          <>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <FilterSelect
                label="Filter by business"
                value={business}
                onChange={setBusiness}
                options={[
                  { value: "all", label: "All businesses" },
                  ...businesses.map((b) => ({ value: b, label: b })),
                ]}
              />
              <FilterSelect
                label="Filter by type"
                value={type}
                onChange={(v) => setType(v as TypeFilter)}
                options={[
                  { value: "all", label: "All types" },
                  { value: "PWD", label: "PWD" },
                  { value: "SENIOR_CITIZEN", label: "Senior" },
                ]}
              />
              <FilterSelect
                label="Filter by result"
                value={result}
                onChange={(v) => setResult(v as ResultFilter)}
                options={[
                  { value: "all", label: "All results" },
                  { value: "valid", label: "Valid" },
                  { value: "invalid", label: "Invalid" },
                ]}
              />
              {hasFilters && (
                <button
                  type="button"
                  onClick={clearFilters}
                  className="text-sm font-medium text-kilala-green hover:underline"
                >
                  Clear
                </button>
              )}
              <span className="ml-auto text-sm text-muted-foreground">
                {filtered.length} of {logs.length}
              </span>
            </div>

            {filtered.length === 0 ? (
              <p className="py-8 text-center text-sm text-muted-foreground">
                No scans match these filters.
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>When</TableHead>
                    <TableHead>Cardholder</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Business</TableHead>
                    <TableHead>Result</TableHead>
                    <TableHead>Reason</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.map((l) => (
                    <TableRow key={l.id}>
                      <TableCell className="whitespace-nowrap font-mono text-xs text-muted-foreground">
                        {formatWhen(l.scanned_at)}
                      </TableCell>
                      <TableCell>
                        <p className="font-bold text-foreground">
                          {l.last_name}, {l.first_name}
                        </p>
                        <p className="font-mono text-xs text-muted-foreground">
                          {l.lgu_id_number}
                        </p>
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant="outline"
                          className="font-medium text-muted-foreground"
                        >
                          {typeLabel(l.privilege_type)}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-foreground">
                        {l.business_name}
                        {l.branch_name ? ` · ${l.branch_name}` : ""}
                      </TableCell>
                      <TableCell>
                        {l.is_valid ? (
                          <Badge variant="secondary">Valid</Badge>
                        ) : (
                          <Badge
                            variant="outline"
                            className="border-destructive/30 text-destructive"
                          >
                            Invalid
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {l.failure_reason || "—"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
