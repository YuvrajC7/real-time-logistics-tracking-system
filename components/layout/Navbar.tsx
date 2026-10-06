'use client'
import Link from 'next/link'
import { Truck } from 'lucide-react'

export function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-4 bg-[#0B1020]/80 backdrop-blur-md border-b border-[#1F2937]">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 bg-[#FFB020] rounded-lg flex items-center justify-center">
          <Truck size={16} className="text-[#0B1020]" />
        </div>
        <span className="font-display font-bold text-lg text-[#F4F1EA]">RTLTS</span>
      </div>
      
      <div className="flex items-center gap-4">
        <Link href="/login" className="text-sm font-medium text-gray-400 hover:text-[#F4F1EA] transition-colors">
          Sign In
        </Link>
        <Link href="/signup" className="btn-primary py-2">
          Get Started
        </Link>
      </div>
    </nav>
  )
}
