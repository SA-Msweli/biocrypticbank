// src/app/layout.tsx
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

// Import headers for SSR context
import { headers } from 'next/headers';
// Import your new ContextProvider
import ContextProvider from '../../context';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'BioCrypticBank MVP', // Updated title
  description: 'Cross-Chain Token Bridge for BioCrypticBank', // Updated description
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Get cookies for SSR initialization of Wagmi
  const cookies = headers().get('cookie');

  return (
    <html lang="en">
      <body className={inter.className}>
        {/* Wrap your application with the ContextProvider */}
        <ContextProvider cookies={cookies}>
          {children}
        </ContextProvider>
      </body>
    </html>
  );
}
