type Point = { month: string; count: number };

const STEP = 500;

export default function RegistrationsChart({
  data,
  className = "",
}: {
  data: Point[];
  className?: string;
}) {
  const max = Math.max(...data.map((d) => d.count));
  const axisMax = Math.ceil(max / STEP) * STEP; // 1720 becomes 2000
  const ticks = Array.from({ length: axisMax / STEP + 1 }, (_, i) => i * STEP);
  const summary = data.map((d) => `${d.month} ${d.count}`).join(", ");

  return (
    <section className={`rounded-2xl bg-white p-5 shadow-sm ${className}`}>
      <h2 className="text-base font-semibold text-ink">
        Registrations over time
      </h2>
      <p className="text-sm text-slate-ink">
        New registrations per month, January to July
      </p>

      <div className="mt-6 flex">
        {/* Y axis labels */}
        <div className="relative h-48 w-12 shrink-0" aria-hidden="true">
          {ticks.map((t) => (
            <span
              key={t}
              className="absolute right-3 translate-y-1/2 text-sm tabular-nums text-slate-ink"
              style={{ bottom: `${(t / axisMax) * 100}%` }}
            >
              {t.toLocaleString()}
            </span>
          ))}
        </div>

        <div className="min-w-0 flex-1">
          {/* Plot area */}
          <div
            role="img"
            aria-label={`Bar chart of registrations per month. ${summary}.`}
            className="relative h-48"
          >
            {ticks.map((t) => (
              <div
                key={t}
                className={`absolute inset-x-0 border-t ${
                  t === 0 ? "border-slate-ink/40" : "border-hairline"
                }`}
                style={{ bottom: `${(t / axisMax) * 100}%` }}
              />
            ))}

            <div className="absolute inset-0 flex gap-3 px-3">
              {data.map((d) => (
                <div
                  key={d.month}
                  className="flex h-full flex-1 flex-col items-center justify-end"
                >
                  <span className="mb-1 hidden text-sm font-medium tabular-nums text-ink lg:block">
                    {d.count.toLocaleString()}
                  </span>
                  <div
                    className="w-full max-w-10 rounded-t-full bg-kilala-green"
                    style={{ height: `${(d.count / axisMax) * 100}%` }}
                  />
                </div>
              ))}
            </div>
          </div>

          {/* Month labels, same flex layout as the bars so they line up */}
          <div className="mt-2 flex gap-3 px-3" aria-hidden="true">
            {data.map((d) => (
              <span
                key={d.month}
                className="flex-1 text-center text-sm text-slate-ink"
              >
                {d.month}
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
