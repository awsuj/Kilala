import Link from "next/link";
import { ArrowRight, type LucideIcon } from "lucide-react";

type StatCardProps = {
  label: string;
  value: string;
  icon: LucideIcon;
  href?: string;
  hint?: string;
  featured?: boolean;
};

export default function StatCard({
  label,
  value,
  icon: Icon,
  href,
  hint,
  featured = false,
}: StatCardProps) {
  return (
    <div
      className={`flex h-full flex-col justify-between rounded-2xl p-5 ${
        featured ? "bg-kilala-green text-white" : "bg-white text-ink shadow-sm"
      }`}
    >
      <div
        className={`flex h-10 w-10 items-center justify-center rounded-xl ${
          featured ? "bg-white/15 text-white" : "bg-surface text-kilala-green"
        }`}
      >
        <Icon className="h-5 w-5" aria-hidden="true" />
      </div>

      <div className="mt-4">
        <p
          className={`text-sm ${featured ? "text-reversed" : "text-slate-ink"}`}
        >
          {label}
        </p>
        <div className="mt-1 flex flex-wrap items-end justify-between gap-x-3 gap-y-1">
          <p className="text-3xl font-semibold tabular-nums">{value}</p>
          {href && hint && (
            <Link
              href={href}
              className={`inline-flex items-center gap-1 rounded-sm pb-1 text-sm font-medium underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 ${
                featured
                  ? "text-white focus-visible:outline-white"
                  : "text-kilala-green hover:text-kilala-green-700 focus-visible:outline-kilala-green"
              }`}
            >
              {hint}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
