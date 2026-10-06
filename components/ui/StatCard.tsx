import { cn } from '@/lib/utils'
import { type LucideIcon } from 'lucide-react'

interface StatCardProps {
  title: string
  value: string | number
  subtitle?: string
  icon?: LucideIcon
  trend?: { value: number; label: string }
  accent?: 'amber' | 'teal' | 'green' | 'red' | 'purple'
  className?: string
}

const ACCENT_CLASSES = {
  amber:  { icon: 'text-amber-400 bg-amber-400/10', border: 'border-amber-400/20' },
  teal:   { icon: 'text-teal-400 bg-teal-400/10',   border: 'border-teal-400/20' },
  green:  { icon: 'text-green-400 bg-green-400/10', border: 'border-green-400/20' },
  red:    { icon: 'text-red-400 bg-red-400/10',     border: 'border-red-400/20' },
  purple: { icon: 'text-purple-400 bg-purple-400/10', border: 'border-purple-400/20' },
}

export function StatCard({ title, value, subtitle, icon: Icon, trend, accent = 'amber', className }: StatCardProps) {
  const colors = ACCENT_CLASSES[accent]
  return (
    <div className={cn(
      'bg-[#111827] border rounded-xl p-6 flex flex-col gap-4',
      colors.border,
      className
    )}>
      <div className="flex items-start justify-between">
        <p className="text-sm text-gray-400 font-medium">{title}</p>
        {Icon && (
          <span className={cn('p-2 rounded-lg', colors.icon)}>
            <Icon size={16} />
          </span>
        )}
      </div>
      <div>
        <p className="text-3xl font-display font-bold text-[#F4F1EA] tabular-nums">{value}</p>
        {subtitle && <p className="text-xs text-gray-500 mt-1">{subtitle}</p>}
      </div>
      {trend && (
        <div className={cn(
          'text-xs font-medium',
          trend.value >= 0 ? 'text-green-400' : 'text-red-400'
        )}>
          {trend.value >= 0 ? '↑' : '↓'} {Math.abs(trend.value)}% {trend.label}
        </div>
      )}
    </div>
  )
}
