export const metadata = { title: "AI Content Workstation" };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: "system-ui, sans-serif", margin: 24 }}>
        {children}
      </body>
    </html>
  );
}
