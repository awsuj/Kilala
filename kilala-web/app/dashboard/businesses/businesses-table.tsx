"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import type { Lgu } from "@/lib/lgus";
import { toggleAccreditation, createBusiness, type NewBusinessInput } from "./actions";
import AddBusinessDialog from "./AddBusinessDialog";

export interface Business {
  id: string;
  business_name: string;
  branch_name: string | null;
  business_permit_no: string;
  email: string | null;
  is_accredited: boolean;
  is_active: boolean;
}

export default function BusinessesTable({
  rows,
  lgus,
}: {
  rows: Business[];
  lgus: Lgu[];
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [, startTransition] = useTransition();
  const accredited = rows.filter((r) => r.is_accredited).length;

  const toggle = (b: Business) => {
    setError(null);
    setPendingId(b.id);
    startTransition(async () => {
      const res = await toggleAccreditation(b.id, !b.is_accredited);
      if (res.error) setError(res.error);
      setPendingId(null);
    });
  };

  const handleAdd = (input: NewBusinessInput) => {
    setError(null);
    startTransition(async () => {
      const res = await createBusiness(input);
      if (res.error) {
        setToast(res.error);
      } else {
        setToast(`${input.businessName} added`);
        router.refresh();
      }
    });
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="space-y-1.5">
              <CardTitle>Businesses</CardTitle>
              <CardDescription>
                {accredited} of {rows.length} accredited · merchants that honor
                PWD & Senior discounts
              </CardDescription>
            </div>
            <AddBusinessDialog
              lgus={lgus}
              existingPermits={rows.map((r) => r.business_permit_no)}
              onAdd={handleAdd}
            />
          </div>
        </CardHeader>
        <CardContent>
          {error && (
            <p className="mb-4 rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
              {error}
            </p>
          )}
          {rows.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              No businesses registered in your LGU yet.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Business</TableHead>
                  <TableHead>Branch</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((b) => (
                  <TableRow key={b.id}>
                    <TableCell className="font-bold text-foreground">
                      {b.business_name}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {b.branch_name || "—"}
                    </TableCell>
                    <TableCell className="font-mono text-xs text-muted-foreground">
                      {b.is_active ? (
                        b.email
                      ) : (
                        <span className="font-sans italic">No account yet</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {b.is_accredited ? (
                        <Badge variant="secondary">Accredited</Badge>
                      ) : (
                        <Badge variant="outline" className="text-muted-foreground">
                          Revoked
                        </Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant={b.is_accredited ? "outline" : "default"}
                        size="sm"
                        disabled={pendingId === b.id}
                        onClick={() => toggle(b)}
                      >
                        {pendingId === b.id
                          ? "Saving…"
                          : b.is_accredited
                            ? "Revoke"
                            : "Re-accredit"}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {toast && (
        <div
          role="status"
          aria-live="polite"
          className="fixed bottom-6 left-1/2 z-[100] -translate-x-1/2 rounded-lg bg-[#11201B] px-4 py-3 text-sm text-white shadow-lg"
        >
          {toast}
        </div>
      )}
    </div>
  );
}
