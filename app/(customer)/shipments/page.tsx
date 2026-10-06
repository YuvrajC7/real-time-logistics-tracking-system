'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { DataTable, type Column } from '@/components/ui/DataTable'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatDate } from '@/lib/utils'
import Link from 'next/link'
import { Plus } from 'lucide-react'

export default function CustomerShipments() {
  const [data, setData] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchShipments() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: shipments } = await supabase
        .from('shipments')
        .select(`
          *,
          packages (description, weight_kg)
        `)
        .eq('sender_id', user.id)
        .order('created_at', { ascending: false })

      setData(shipments || [])
      setLoading(false)
    }
    fetchShipments()
  }, [])

  const cols: Column<any>[] = [
    { key: 'tracking_no', header: 'Tracking No', sortable: true, className: 'font-mono' },
    { key: 'receiver_name', header: 'Receiver', sortable: true },
    { key: 'service_type', header: 'Service' },
    { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status} /> },
    { key: 'packages', header: 'Items', render: (r) => r.packages?.length || 0 },
    { key: 'created_at', header: 'Created', sortable: true, render: (r) => formatDate(r.created_at) },
  ]

  if (loading) return <div>Loading shipments...</div>

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">My Shipments</h1>
          <p className="text-gray-400 mt-1">Manage and track all your outgoing parcels.</p>
        </div>
        <Link href="/customer/shipments/new" className="btn-primary">
          <Plus size={16} /> New Shipment
        </Link>
      </div>

      <div className="card">
        <DataTable
          columns={cols}
          data={data}
          keyField="shipment_id"
          searchable
          searchKeys={['tracking_no', 'receiver_name']}
        />
      </div>
    </div>
  )
}
