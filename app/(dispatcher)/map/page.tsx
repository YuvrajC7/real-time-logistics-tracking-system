'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { StatCard } from '@/components/ui/StatCard'
import { Map, Truck, Package, AlertCircle } from 'lucide-react'
import { DataTable } from '@/components/ui/DataTable'
import { StatusBadge } from '@/components/ui/StatusBadge'

export default function DispatcherDashboard() {
  const [stats, setStats] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    async function fetchStats() {
      const supabase = createClient()
      const { data, error } = await supabase.rpc('get_dispatcher_stats')
      if (data) setStats(data)
      setLoading(false)
    }
    fetchStats()
    // Poll every 30s
    const int = setInterval(fetchStats, 30000)
    return () => clearInterval(int)
  }, [])

  if (loading) return <div className="p-8">Loading control tower...</div>

  return (
    <div className="p-8 space-y-8">
      <div>
        <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">Live Operations</h1>
        <p className="text-gray-400 mt-1">Real-time telemetry and network status.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatCard title="Active Trips" value={stats?.active_trips || 0} icon={Truck} accent="teal" />
        <StatCard title="Shipments in Transit" value={stats?.in_transit_shipments || 0} icon={Package} accent="amber" />
        <StatCard title="Delayed / Alerts" value={stats?.delayed_shipments || 0} icon={AlertCircle} accent="red" />
        <StatCard title="Hubs Operational" value={stats?.active_hubs || 0} icon={Map} accent="purple" />
      </div>
      
      {/* Mini live map could go here or a table of critical alerts */}
      <div className="card h-96 flex items-center justify-center border-dashed">
         <p className="text-gray-500">Live Telemetry Map goes here (MapLibre)</p>
      </div>
    </div>
  )
}
