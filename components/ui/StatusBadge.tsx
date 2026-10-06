import { cn } from '@/lib/utils'
import type { ShipmentStatus } from '@/lib/supabase/types'

const STATUS_CONFIG: Record<ShipmentStatus, { label: string; dot: string; text: string; bg: string }> = {
  CREATED:          { label: 'Created',          dot: 'bg-gray-500',   text: 'text-gray-400',   bg: 'bg-gray-500/10' },
  PICKED_UP:        { label: 'Picked Up',        dot: 'bg-blue-500',   text: 'text-blue-400',   bg: 'bg-blue-500/10' },
  IN_TRANSIT:       { label: 'In Transit',       dot: 'bg-amber-500',  text: 'text-amber-400',  bg: 'bg-amber-500/10' },
  AT_HUB:           { label: 'At Hub',           dot: 'bg-purple-500', text: 'text-purple-400', bg: 'bg-purple-500/10' },
  OUT_FOR_DELIVERY: { label: 'Out for Delivery', dot: 'bg-teal-500',   text: 'text-teal-400',   bg: 'bg-teal-500/10 animate-pulse' },
  DELIVERED:        { label: 'Delivered',        dot: 'bg-green-500',  text: 'text-green-400',  bg: 'bg-green-500/10' },
  FAILED_ATTEMPT:   { label: 'Failed Attempt',   dot: 'bg-red-500',    text: 'text-red-400',    bg: 'bg-red-500/10' },
  RETURNED:         { label: 'Returned',         dot: 'bg-orange-500', text: 'text-orange-400', bg: 'bg-orange-500/10' },
  CANCELLED:        { label: 'Cancelled',        dot: 'bg-gray-600',   text: 'text-gray-500',   bg: 'bg-gray-600/10' },
}

interface StatusBadgeProps {
  status: ShipmentStatus
  size?: 'sm' | 'md' | 'lg'
  showDot?: boolean
  className?: string
}

export function StatusBadge({ status, size = 'md', showDot = true, className }: StatusBadgeProps) {
  const cfg = STATUS_CONFIG[status]
  const sizeClasses = {
    sm: 'text-xs px-2 py-0.5 gap-1',
    md: 'text-xs px-2.5 py-1 gap-1.5',
    lg: 'text-sm px-3 py-1.5 gap-2',
  }
  return (
    <span className={cn(
      'inline-flex items-center rounded-full font-mono font-medium',
      cfg.bg, cfg.text, sizeClasses[size], className
    )}>
      {showDot && (
        <span className={cn('rounded-full flex-shrink-0', cfg.dot,
          size === 'sm' ? 'w-1.5 h-1.5' : size === 'lg' ? 'w-2.5 h-2.5' : 'w-2 h-2'
        )} />
      )}
      {cfg.label}
    </span>
  )
}
