"use client";

import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";

type Props = {
  filename: string;
  headers: string[];
  rows: (string | number)[][];
};

/** Client-side CSV download for a report table — no server round-trip. */
export default function ExportCsvButton({ filename, headers, rows }: Props) {
  const exportCsv = () => {
    const csvCell = (v: string | number) => `"${String(v).replace(/"/g, '""')}"`;
    const csv = [headers, ...rows]
      .map((row) => row.map(csvCell).join(","))
      .join("\r\n");
    // Prepend a BOM so Excel reads UTF-8 (₱, ñ, é) correctly.
    const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      onClick={exportCsv}
      disabled={rows.length === 0}
    >
      <Download className="size-4" /> Export CSV
    </Button>
  );
}
