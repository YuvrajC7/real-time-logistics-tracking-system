import type { Metadata } from 'next'
import './globals.css'
import { Toaster } from 'sonner'

export const metadata: Metadata = {
  title: 'RTLTS — Real-Time Logistics Tracking',
  description: 'Track shipments live. Manage fleets. Deliver faster.',
  keywords: ['logistics', 'tracking', 'shipment', 'fleet management'],
  openGraph: {
    title: 'RTLTS — Real-Time Logistics Tracking',
    description: 'Track shipments live. Manage fleets. Deliver faster.',
    type: 'website',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="bg-ink text-off-white antialiased">
        {children}
        <Toaster
          position="bottom-right"
          theme="dark"
          toastOptions={{
            style: {
              background: '#111827',
              border: '1px solid #1F2937',
              color: '#F4F1EA',
              fontFamily: 'Inter, sans-serif',
            },
          }}
        />
      </body>
    </html>
  )
}
