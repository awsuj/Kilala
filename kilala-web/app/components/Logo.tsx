/**
 * Kilala brand mark — scan brackets + check ("scanned and recognized").
 * The yellow (sunrise) check is the only spot of accent, per Brand
 * Guidelines v0.1 §01 Logo. `reversed` renders it for dark surfaces.
 */
export default function Logo({
  showWordmark = true,
  reversed = false,
  className = "",
}: {
  showWordmark?: boolean;
  reversed?: boolean;
  className?: string;
}) {
  const bracket = reversed ? "#ffffff" : "var(--color-kilala-green)";

  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <svg
        viewBox="0 0 24 24"
        className="h-7 w-7 shrink-0"
        fill="none"
        aria-hidden="true"
      >
        <g
          stroke={bracket}
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M4 8V6a2 2 0 0 1 2-2h2" />
          <path d="M16 4h2a2 2 0 0 1 2 2v2" />
          <path d="M20 16v2a2 2 0 0 1-2 2h-2" />
          <path d="M8 20H6a2 2 0 0 1-2-2v-2" />
        </g>
        <path
          d="M8.4 12.3l2.4 2.4 4.8-5"
          stroke="var(--color-sunrise)"
          strokeWidth="2.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      {showWordmark && (
        <span
          className={`text-2xl font-extrabold lowercase tracking-tight ${
            reversed ? "text-white" : "text-kilala-green"
          }`}
        >
          kilala
        </span>
      )}
    </span>
  );
}
