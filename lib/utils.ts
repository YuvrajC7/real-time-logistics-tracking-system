import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
import type { ShipmentStatus, ServiceType } from '@/lib/supabase/types'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2,
  }).format(amount)
}

export function formatDate(date: string | Date): string {
  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(date))
}

export function formatRelativeTime(date: string | Date): string {
  const now = new Date()
  const d = new Date(date)
  const diffMs = now.getTime() - d.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin < 1) return 'just now'
  if (diffMin < 60) return `${diffMin}m ago`
  const diffHr = Math.floor(diffMin / 60)
  if (diffHr < 24) return `${diffHr}h ago`
  const diffDay = Math.floor(diffHr / 24)
  return `${diffDay}d ago`
}

export const STATUS_CONFIG: Record<ShipmentStatus, { label: string; color: string; bg: string }> = {
  CREATED:          { label: 'Created',           color: 'text-gray-400',   bg: 'bg-gray-900/50' },
  PICKED_UP:        { label: 'Picked Up',         color: 'text-blue-400',   bg: 'bg-blue-900/30' },
  IN_TRANSIT:       { label: 'In Transit',        color: 'text-amber-400',  bg: 'bg-amber-900/30' },
  AT_HUB:           { label: 'At Hub',            color: 'text-purple-400', bg: 'bg-purple-900/30' },
  OUT_FOR_DELIVERY: { label: 'Out for Delivery',  color: 'text-teal-400',   bg: 'bg-teal-900/30' },
  DELIVERED:        { label: 'Delivered',         color: 'text-green-400',  bg: 'bg-green-900/30' },
  FAILED_ATTEMPT:   { label: 'Failed Attempt',    color: 'text-red-400',    bg: 'bg-red-900/30' },
  RETURNED:         { label: 'Returned',          color: 'text-orange-400', bg: 'bg-orange-900/30' },
  CANCELLED:        { label: 'Cancelled',         color: 'text-gray-500',   bg: 'bg-gray-900/20' },
}

export const SERVICE_LABELS: Record<ServiceType, string> = {
  STANDARD: 'Standard (3-5 days)',
  EXPRESS:  'Express (1-2 days)',
  SAME_DAY: 'Same Day',
}

export function interpolatePosition(
  from: { lat: number; lng: number },
  to: { lat: number; lng: number },
  t: number
) {
  return {
    lat: from.lat + (to.lat - from.lat) * t,
    lng: from.lng + (to.lng - from.lng) * t,
  }
}
