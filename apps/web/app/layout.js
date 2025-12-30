import "./globals.css";
import AppShell from "./_components/AppShell";

export const metadata = {
  title: "AI Content Workstation",
  description: "P0 UI (Batch-3)"
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
