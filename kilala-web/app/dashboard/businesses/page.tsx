"use client";

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
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";

// Mock data — maps to GET /api/lgu/businesses. Accreditation toggle is local
// preview for now; wires to PATCH /api/lgu/businesses/:id/accreditation later.
const seed = [
  { id: "1", name: "Mercury Drug", branch: "Makati Ave", email: "cashier@mercury-mkt.com", accredited: true },
  { id: "2", name: "Tinuhog Ni Benny", branch: "Poblacion", email: "benny@tinuhog.ph", accredited: true },
  { id: "3", name: "SM Supermarket", branch: "Makati Central", email: "mkt@sm.com.ph", accredited: true },
  { id: "4", name: "Aling Nena Sari-Sari", branch: "Pembo", email: "nena@email.com", accredited: false },
  { id: "5", name: "Botika ng Barangay", branch: "Guadalupe", email: "bnb@guadalupe.ph", accredited: true },
];

export default function BusinessesPage() {
  const [rows, setRows] = useState(seed);
  const accredited = rows.filter((r) => r.accredited).length;

  const toggle = (id: string) =>
    setRows((rs) =>
      rs.map((b) => (b.id === id ? { ...b, accredited: !b.accredited } : b)),
    );

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Businesses</CardTitle>
          <CardDescription>
            {accredited} of {rows.length} accredited · merchants that honor PWD &
            Senior discounts
          </CardDescription>
        </CardHeader>
        <CardContent>
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
                  <TableCell className="font-bold text-foreground">{b.name}</TableCell>
                  <TableCell className="text-muted-foreground">{b.branch}</TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {b.email}
                  </TableCell>
                  <TableCell>
                    {b.accredited ? (
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
                      variant={b.accredited ? "outline" : "default"}
                      size="sm"
                      onClick={() => toggle(b.id)}
                    >
                      {b.accredited ? "Revoke" : "Re-accredit"}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
