import '../styles/globals.scss';

export const metadata = {
  title: 'Sick Scents',
  description: 'Next App Router + SCSS baseline',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
