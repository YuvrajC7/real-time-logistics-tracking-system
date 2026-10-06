import { cn, formatDate } from '@/lib/utils'
import { StatusBadge } from './StatusBadge'
import type { ShipmentStatus } from '@/lib/supabase/types'

interface TimelineEvent {
  status: ShipmentStatus
  hub_name?: string | null
  note?: string | null
  created_at: string
}

interface TimelineProps {
  events: TimelineEvent[]
  className?: string
}

export function Timeline({ events, className }: TimelineProps) {
  return (
    <div className={cn('relative', className)}>
      <div className="absolute left-[18px] top-0 bottom-0 w-px bg-[#1F2937]" />
      <div className="space-y-6">
        {events.map((event, i) => (
          <div key={i} className="flex gap-4 relative">
            <div className={cn(
              'w-9 h-9 rounded-full flex-shrink-0 flex items-center justify-center z-10 border-2',
              i === 0
                ? 'bg-[#FFB020] border-[#FFB020] text-[#0B1020]'
                : 'bg-[#111827] border-[#1F2937]'
            )}>
              <span className="text-xs font-bold">{events.length - i}</span>
            </div>
            <div className="flex-1 min-w-0 pt-1.5">
              <div className="flex items-center gap-2 flex-wrap">
                <StatusBadge status={event.status} size="sm" />
                {event.hub_name && (
                  <span className="text-xs text-gray-500">· {event.hub_name}</span>
                )}
              </div>
              {event.note && (
                <p className="text-xs text-gray-400 mt-1">{event.note}</p>
              )}
              <p className="text-xs text-gray-600 mt-1 font-mono">{formatDate(event.created_at)}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
