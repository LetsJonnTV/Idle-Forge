import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Idle Forge',
  description: 'Idle Forge — Inventory Manager',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
