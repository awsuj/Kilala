import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Kilala · LGU Portal",
  description: "LGU Web Portal for the Kilala PWD & Senior Citizen record system.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col font-sans">{children}</body>
    </html>
  );
}
