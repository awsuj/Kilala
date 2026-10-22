export default function TopBar({ title }: { title: string }) {
  return (
    <header className="flex items-center justify-between border-b border-hairline bg-white px-6 py-3">
      <h1 className="text-xl font-bold text-ink">{title}</h1>

      <div>
        <label htmlFor="search" className="sr-only">
          Search
        </label>
        <input
          id="search"
          type="search"
          placeholder="Search records..."
          className="w-56 rounded-lg border border-hairline px-3 py-1.5 text-sm text-ink"
        />
      </div>
    </header>
  );
}
