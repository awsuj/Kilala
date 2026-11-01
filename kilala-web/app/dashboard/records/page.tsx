"use client";

import type { CardRecord, NewRecordInput, Status } from "./types";
import AddRecordDialog from "./AddRecordDialog";
import { computeExpiry, todayLocal } from "./rules";

import { useState } from "react";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
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

// Mock data. Will map to the cardholders API later
const seed: CardRecord[] = [
  {
    id: "13-7405-000-0000231",
    name: "Santos, Pedro L.",
    type: "PWD",
    expiry: "2026-11-20", // expiring soon
    status: "Active",
  },
  {
    id: "13-7404-000-0001874",
    name: "Reyes, Ana M.",
    type: "PWD",
    expiry: "2025-09-12",
    status: "Expired",
  },
  {
    id: "13-7403-000-0004102",
    name: "Garcia, Jose R.",
    type: "PWD",
    expiry: null, // permanent disability, lifetime card
    status: "Active",
  },
  {
    id: "13-7405-000-0000987",
    name: "Tan, Mark A.",
    type: "PWD",
    expiry: "2027-07-08", // 3-year legacy card
    status: "Active",
  },
  {
    id: "13-7404-000-0002650",
    name: "Mendoza, Carlo B.",
    type: "PWD",
    expiry: "2028-01-30",
    status: "Suspended",
  },
  {
    id: "QC-SC-2021-004512",
    name: "Dela Cruz, Maria S.",
    type: "Senior",
    expiry: null,
    status: "Active",
  },
  {
    id: "QC-SC-2019-001387",
    name: "Lim, Grace T.",
    type: "Senior",
    expiry: null,
    status: "Suspended",
  },
  {
    id: "SJ-SC-2023-000764",
    name: "Bautista, Liza C.",
    type: "Senior",
    expiry: null,
    status: "Active",
  },
];

const badgeVariant = (
  status: Status,
): "secondary" | "outline" | "destructive" => {
  switch (status) {
    case "Active":
      return "secondary";
    case "Expired":
      return "outline";
    case "Suspended":
      return "destructive";
  }
};

export default function RecordsPage() {
  const [rows, setRows] = useState(seed);
  const [query, setQuery] = useState("");

  const active = rows.filter((r) => r.status === "Active").length;

  const q = query.trim().toLowerCase();

  const filtered = rows.filter((r) => {
    return r.name.toLowerCase().includes(q) || r.id.toLowerCase().includes(q);
  });

  const toggleSuspend = (id: string) =>
    setRows((rs) =>
      rs.map((r) => {
        if (r.id !== id || r.status === "Expired") return r;
        const next: Status = r.status === "Active" ? "Suspended" : "Active";
        return { ...r, status: next };
      }),
    );

  const handleAdd = (input: NewRecordInput) => {
    const expiry = computeExpiry(
      input.issuingDate,
      input.pwd?.disabilityNature ?? null,
      input.pwd?.cardSystemType ?? null,
    );
    const middle = input.middleName
      ? ` ${input.middleName[0].toUpperCase()}.`
      : "";
    const record: CardRecord = {
      id: input.cardNumber,
      name: `${input.lastName}, ${input.firstName}${middle}`,
      type: input.privilegeType,
      expiry,
      // an old card can already be expired the moment it's encoded
      status: expiry && expiry < todayLocal() ? "Expired" : "Active",
    };
    setRows((rs) => [record, ...rs]);
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Records</CardTitle>
          <CardDescription>
            {active} of {rows.length} active, PWD and Senior Citizen cardholders
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-4">
          {/* Toolbar */}
          <div className="flex items-center justify-between gap-4">
            <div className="w-full max-w-sm">
              <label htmlFor="record-search" className="sr-only">
                Search by ID or name
              </label>
              <Input
                id="record-search"
                type="search"
                placeholder="Search by ID or name..."
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
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
                <TableHead>Name</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Expiry</TableHead>
                <TableHead className="w-40">Status</TableHead>
                <TableHead className="w-40 text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={6}
                    className="text-center text-muted-foreground"
                  >
                    No records match your search.
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-mono text-xs">{r.id}</TableCell>
                    <TableCell className="font-bold text-foreground">
                      {r.name}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {r.type}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {r.expiry ?? "Lifetime"}
                    </TableCell>
                    <TableCell>
                      <Badge variant={badgeVariant(r.status)}>{r.status}</Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant={
                          r.status === "Suspended" ? "default" : "outline"
                        }
                        size="sm"
                        disabled={r.status === "Expired"}
                        onClick={() => toggleSuspend(r.id)}
                      >
                        {r.status === "Suspended" ? "Reinstate" : "Suspend"}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
