"use client";

import { useState } from "react";
import StatCard from "../components/StatCard";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardAction,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

// ---------------------------------------------------------------------------
// Mock monthly series (wired to GET /api/lgu/dashboard later). Hovering a
// month in the chart drives the stat cards + Total Verifications panel.
// ---------------------------------------------------------------------------
const monthly = [
  { m: "Jan", v: 820 },
  { m: "Feb", v: 760 },
  { m: "Mar", v: 940 },
  { m: "Apr", v: 900 },
  { m: "May", v: 1080 },
  { m: "Jun", v: 1150 },
  { m: "Jul", v: 1040 },
  { m: "Aug", v: 1280 },
  { m: "Sep", v: 1360 },
  { m: "Oct", v: 1300 },
  { m: "Nov", v: 1540 },
  { m: "Dec", v: 1720 },
];
const values = monthly.map((d) => d.v);
const maxV = Math.max(...values);

const cum = (() => {
  const a: number[] = [];
  let s = 0;
  for (const v of values) {
    s += v;
    a.push(s);
  }
  return a;
})();
const cmax = cum[cum.length - 1];
/** A monotonic series ending at `end`, starting at end*startFrac. */
const grow = (end: number, startFrac: number) =>
  cum.map((c) => Math.round(end * (startFrac + (1 - startFrac) * (c / cmax))));

const registeredS = grow(12480, 0.45);
const businessS = grow(356, 0.6);
const verifS = values.map((v) => Math.round((1284 * v) / maxV));
const totalVerifS = grow(128540, 0.4);
const validS = totalVerifS.map((t) => Math.round((t * 124910) / 128540));
const expiredS = totalVerifS.map((t) => Math.round((t * 2180) / 128540));
const notrecS = totalVerifS.map((t) => Math.round((t * 1450) / 128540));

const fmt = (n: number) => n.toLocaleString();

/** Catmull-Rom → cubic Bézier, for a smooth trend line through the points. */
function smoothPath(pts: { x: number; y: number }[]) {
  if (pts.length < 2) return "";
  let d = `M ${pts[0].x},${pts[0].y}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] ?? pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2] ?? p2;
    const c1x = p1.x + (p2.x - p0.x) / 6;
    const c1y = p1.y + (p2.y - p0.y) / 6;
    const c2x = p2.x - (p3.x - p1.x) / 6;
    const c2y = p2.y - (p3.y - p1.y) / 6;
    d += ` C ${c1x},${c1y} ${c2x},${c2y} ${p2.x},${p2.y}`;
  }
  return d;
}

function MonthlyChart({
  active,
  onHover,
}: {
  active: number;
  onHover: (i: number | null) => void;
}) {
  const W = 680;
  const H = 240;
  const top = 34;
  const bottom = 26;
  const padX = 2;
  const innerH = H - top - bottom;
  const slot = (W - padX * 2) / values.length;
  const bw = slot * 0.5;
  const grid = [0, 0.25, 0.5, 0.75, 1].map((f) => top + innerH * f);

  const pts = values.map((v, i) => ({
    x: padX + i * slot + slot / 2,
    y: top + innerH - (v / maxV) * innerH,
  }));
  const line = smoothPath(pts);
  const act = pts[active];
  const tipX = Math.min(Math.max(act.x, padX + 34), W - padX - 34);

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      className="mt-2 h-60 w-full"
      role="img"
      aria-label="New cardholders per month with trend line"
      onMouseLeave={() => onHover(null)}
    >
      {grid.map((y, i) => (
        <line key={i} x1={padX} x2={W - padX} y1={y} y2={y} stroke="var(--color-border)" strokeWidth="1" strokeDasharray={i === grid.length - 1 ? "0" : "3 4"} />
      ))}

      {values.map((v, i) => {
        const bh = (v / maxV) * innerH;
        const x = padX + i * slot + (slot - bw) / 2;
        return (
          <rect key={i} x={x} y={top + innerH - bh} width={bw} height={bh} rx={2} fill={i === active ? "var(--color-primary)" : "var(--color-secondary)"} />
        );
      })}

      {/* Trend line overlay */}
      <path d={line} fill="none" stroke="var(--color-primary)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={act.x} cy={act.y} r="4" fill="var(--color-primary)" stroke="white" strokeWidth="2" />

      {/* Tooltip on the active month */}
      <g>
        <rect x={tipX - 34} y={top - 26} width="68" height="22" rx="6" fill="var(--color-primary)" />
        <text x={tipX} y={top - 11} textAnchor="middle" className="fill-white text-[11px] font-bold">
          {fmt(values[active])}
        </text>
      </g>

      {monthly.map((d, i) => (
        <text key={d.m} x={pts[i].x} y={H - 8} textAnchor="middle" className="fill-muted-foreground text-[10px]">
          {d.m}
        </text>
      ))}

      {/* Invisible hover zones */}
      {values.map((_, i) => (
        <rect key={`h${i}`} x={padX + i * slot} y={top} width={slot} height={innerH} fill="transparent" onMouseEnter={() => onHover(i)} />
      ))}
    </svg>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-2.5">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="font-mono text-sm font-bold text-foreground">{value}</span>
    </div>
  );
}

export default function DashboardOverview() {
  const N = values.length;
  const [hover, setHover] = useState<number | null>(null);
  const active = hover ?? N - 1;
  const note = hover !== null ? `${monthly[active].m} 2026` : undefined;

  return (
    <div className="space-y-6">
      {/* Stat cards — update on chart hover */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <StatCard label="Registered Cardholders" value={fmt(registeredS[active])} delta="2.3%" deltaDir="up" note={note} spark={registeredS} activeIndex={active} />
        <StatCard label="Accredited Businesses" value={fmt(businessS[active])} delta="5.1%" deltaDir="up" note={note} spark={businessS} activeIndex={active} />
        <StatCard label="Verifications" value={fmt(verifS[active])} delta="1.4%" deltaDir="down" note={note} spark={verifS} activeIndex={active} />
      </div>

      {/* Chart + highlight panel */}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader>
            <CardTitle>Registrations over time</CardTitle>
            <CardDescription>New cardholders per month</CardDescription>
            <CardAction>
              <Badge variant="outline">Last 12 months</Badge>
            </CardAction>
          </CardHeader>
          <CardContent>
            <MonthlyChart active={active} onHover={setHover} />
          </CardContent>
        </Card>

        <Card className="bg-secondary">
          <CardHeader>
            <CardDescription>
              Total Verifications{note ? ` · ${note}` : ""}
            </CardDescription>
            <CardTitle className="text-4xl font-extrabold tracking-tight">
              {fmt(totalVerifS[active])}
            </CardTitle>
            <CardAction>
              <span className="text-xs font-bold text-[var(--color-valid)]">▲ 20%</span>
            </CardAction>
          </CardHeader>
          <CardContent className="mt-auto border-t border-border pt-2">
            <div className="divide-y divide-border">
              <Row label="Valid" value={fmt(validS[active])} />
              <Row label="Expired" value={fmt(expiredS[active])} />
              <Row label="Not recognized" value={fmt(notrecS[active])} />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
