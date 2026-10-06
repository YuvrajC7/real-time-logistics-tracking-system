'use client'
import { useState, useMemo } from 'react'
import { cn } from '@/lib/utils'
import { ChevronUp, ChevronDown, Search } from 'lucide-react'

export interface Column<T> {
  key: keyof T | string
  header: string
  render?: (row: T) => React.ReactNode
  sortable?: boolean
  className?: string
}

interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  keyField: keyof T
  searchable?: boolean
  searchKeys?: (keyof T)[]
  pageSize?: number
  emptyMessage?: string
  className?: string
  onRowClick?: (row: T) => void
}

export function DataTable<T extends Record<string, unknown>>({
  columns, data, keyField, searchable, searchKeys = [], pageSize = 20,
  emptyMessage = 'No data found.', className, onRowClick,
}: DataTableProps<T>) {
  const [search, setSearch] = useState('')
  const [sortKey, setSortKey] = useState<string | null>(null)
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const [page, setPage] = useState(1)

  const filtered = useMemo(() => {
    if (!search) return data
    const q = search.toLowerCase()
    return data.filter(row =>
      searchKeys.some(k => String(row[k] ?? '').toLowerCase().includes(q))
    )
  }, [data, search, searchKeys])

  const sorted = useMemo(() => {
    if (!sortKey) return filtered
    return [...filtered].sort((a, b) => {
      const av = a[sortKey as keyof T] as string | number
      const bv = b[sortKey as keyof T] as string | number
      const cmp = av < bv ? -1 : av > bv ? 1 : 0
      return sortDir === 'asc' ? cmp : -cmp
    })
  }, [filtered, sortKey, sortDir])

  const totalPages = Math.ceil(sorted.length / pageSize)
  const paged = sorted.slice((page - 1) * pageSize, page * pageSize)

  const handleSort = (key: string) => {
    if (sortKey === key) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    } else {
      setSortKey(key)
      setSortDir('asc')
    }
    setPage(1)
  }

  return (
    <div className={cn('flex flex-col gap-4', className)}>
      {searchable && (
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" />
          <input
            className="input-base pl-9 max-w-sm"
            placeholder="Search..."
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1) }}
          />
        </div>
      )}
      <div className="overflow-x-auto rounded-xl border border-[#1F2937]">
        <table className="w-full">
          <thead>
            <tr className="border-b border-[#1F2937]">
              {columns.map(col => (
                <th
                  key={String(col.key)}
                  className={cn(
                    'px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider whitespace-nowrap',
                    col.sortable && 'cursor-pointer select-none hover:text-[#F4F1EA]',
                    col.className
                  )}
                  onClick={() => col.sortable && handleSort(String(col.key))}
                >
                  <span className="flex items-center gap-1">
                    {col.header}
                    {col.sortable && sortKey === String(col.key) && (
                      sortDir === 'asc' ? <ChevronUp size={12} /> : <ChevronDown size={12} />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-[#1F2937]">
            {paged.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-12 text-center text-gray-500 text-sm">
                  {emptyMessage}
                </td>
              </tr>
            ) : paged.map(row => (
              <tr
                key={String(row[keyField])}
                className={cn(
                  'hover:bg-white/[0.02] transition-colors',
                  onRowClick && 'cursor-pointer'
                )}
                onClick={() => onRowClick?.(row)}
              >
                {columns.map(col => (
                  <td key={String(col.key)} className={cn('px-4 py-3 text-sm text-[#F4F1EA]', col.className)}>
                    {col.render ? col.render(row) : String(row[col.key as keyof T] ?? '—')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {totalPages > 1 && (
        <div className="flex items-center justify-between text-sm text-gray-500">
          <span>{sorted.length} results</span>
          <div className="flex items-center gap-2">
            <button
              className="btn-ghost py-1 px-2 text-xs disabled:opacity-30"
              onClick={() => setPage(p => p - 1)} disabled={page === 1}
            >Prev</button>
            <span className="text-[#F4F1EA] font-mono text-xs">{page} / {totalPages}</span>
            <button
              className="btn-ghost py-1 px-2 text-xs disabled:opacity-30"
              onClick={() => setPage(p => p + 1)} disabled={page === totalPages}
            >Next</button>
          </div>
        </div>
      )}
    </div>
  )
}
