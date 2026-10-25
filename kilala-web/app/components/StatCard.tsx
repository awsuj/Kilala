import { Card } from "@/components/ui/card";

type StatCardProps = {
  label: string;
  value: string;
  delta?: string;
  deltaDir?: "up" | "down";
  spark?: number[];
  /** Which bar to highlight (follows chart hover). Defaults to the last. */
  activeIndex?: number;
  /** When set (e.g. on chart hover), replaces the delta line with context. */
  note?: string;
};

/** Mini bar sparkline — the bar at activeIndex is the accent. */
function Sparkbars({ data, activeIndex }: { data: number[]; activeIndex: number }) {
  const max = Math.max(...data);
  const w = 5;
  const gap = 3;
  const h = 44;
  const totalW = data.length * (w + gap) - gap;

  return (
    <svg
      width={totalW}
      height={h}
      viewBox={`0 0 ${totalW} ${h}`}
      className="shrink-0"
      aria-hidden="true"
    >
      {data.map((v, i) => {
        const bh = Math.max(3, (v / max) * h);
        const active = i === activeIndex;
        return (
          <rect
            key={i}
            x={i * (w + gap)}
            y={h - bh}
            width={w}
            height={bh}
            rx={1.5}
            fill={active ? "var(--color-primary)" : "rgba(14,91,74,0.18)"}
          />
        );
      })}
    </svg>
  );
}

export default function StatCard({
  label,
  value,
  delta,
  deltaDir = "up",
  spark,
  activeIndex,
  note,
}: StatCardProps) {
  const deltaCls =
    deltaDir === "up" ? "text-[var(--color-valid)]" : "text-destructive";
  const ai = activeIndex ?? (spark ? spark.length - 1 : 0);

  return (
    <Card className="gap-0 p-5">
      <p className="text-sm font-bold text-muted-foreground">{label}</p>

      <div className="mt-4 flex items-end justify-between gap-4">
        <div>
          <p className="text-3xl font-extrabold leading-none tracking-tight">
            {value}
          </p>
          {note ? (
            <p className="mt-2 text-xs font-bold text-muted-foreground">{note}</p>
          ) : delta ? (
            <p className={`mt-2 text-xs font-bold ${deltaCls}`}>
              {deltaDir === "up" ? "▲" : "▼"} {delta}{" "}
              <span className="text-muted-foreground">than last month</span>
            </p>
          ) : null}
        </div>
        {spark && <Sparkbars data={spark} activeIndex={ai} />}
      </div>
    </Card>
  );
}
