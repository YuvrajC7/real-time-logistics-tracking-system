'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { StatCard } from '@/components/ui/StatCard'
import { DataTable, type Column } from '@/components/ui/DataTable'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { Package, Clock, CheckCircle, AlertCircle } from 'lucide-react'
import { formatCurrency, formatDate } from '@/lib/utils'

export default function CustomerDashboard() {
  const [stats, setStats] = useState({ total: 0, active: 0, delivered: 0, alerts: 0 })
  const [recent, setRecent] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadData() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: shipments } = await supabase
        .from('shipments')
        .select('*')
        .eq('sender_id', user.id)
        .order('created_at', { ascending: false })

      if (shipments) {
        setStats({
          total: shipments.length,
          active: shipments.filter(s => !['DELIVERED', 'CANCELLED', 'RETURNED'].includes(s.status)).length,
          delivered: shipments.filter(s => s.status === 'DELIVERED').length,
          alerts: shipments.filter(s => s.status === 'FAILED_ATTEMPT').length,
        })
        setRecent(shipments.slice(0, 5))
      }
      setLoading(false)
    }
    loadData()
  }, [])

  const cols: Column<any>[] = [
    { key: 'tracking_no', header: 'Tracking No', className: 'font-mono' },
    { key: 'receiver_name', header: 'Receiver' },
    { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status} /> },
    { key: 'created_at', header: 'Date', render: (r) => formatDate(r.created_at) },
  ]

  if (loading) return <div>Loading dashboard...</div>

  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">Dashboard</h1>
        <p className="text-gray-400 mt-1">Overview of your logistics activity.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="Total Shipments" value={stats.total} icon={Package} accent="amber" />
        <StatCard title="Active In-Transit" value={stats.active} icon={Clock} accent="teal" />
        <StatCard title="Delivered" value={stats.delivered} icon={CheckCircle} accent="green" />
        <StatCard title="Alerts / Exceptions" value={stats.alerts} icon={AlertCircle} accent="red" />
      </div>

      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-[#F4F1EA]">Recent Shipments</h2>
        </div>
        <DataTable columns={cols} data={recent} keyField="shipment_id" />
      </div>
    </div>
  )
}
