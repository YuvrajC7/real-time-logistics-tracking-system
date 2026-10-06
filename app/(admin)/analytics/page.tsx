'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { StatCard } from '@/components/ui/StatCard'
import { DataTable } from '@/components/ui/DataTable'
import { BarChart3, Users, IndianRupee, TrendingUp } from 'lucide-react'
import { formatCurrency, formatDate } from '@/lib/utils'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

export default function AdminAnalytics() {
  const [kpis, setKpis] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data } = await supabase.from('mv_daily_kpis').select('*').order('day', { ascending: true }).limit(14)
      if (data) setKpis(data)
      setLoading(false)
    }
    load()
  }, [])

  const latest = kpis[kpis.length - 1] || { total_shipments: 0, total_revenue: 0, delivery_rate_pct: 0 }

  if (loading) return <div>Loading reports...</div>

  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">Platform Analytics</h1>
        <p className="text-gray-400 mt-1">System-wide performance and revenue metrics.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatCard title="Daily Volume" value={latest.total_shipments} icon={Package} accent="amber" />
        <StatCard title="Revenue (Today)" value={formatCurrency(latest.total_revenue)} icon={IndianRupee} accent="green" />
        <StatCard title="Delivery Rate" value={`${latest.delivery_rate_pct}%`} icon={TrendingUp} accent="teal" />
        <StatCard title="Active Users" value={42} icon={Users} accent="purple" />
      </div>

      <div className="grid md:grid-cols-2 gap-8">
        <div className="card h-96">
          <h2 className="text-lg font-semibold mb-6">Revenue Trend (14 days)</h2>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={kpis}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1F2937" vertical={false} />
              <XAxis dataKey="day" tickFormatter={t => new Date(t).getDate().toString()} stroke="#6B7280" />
              <YAxis stroke="#6B7280" tickFormatter={v => `₹${v/1000}k`} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#111827', borderColor: '#1F2937' }}
                itemStyle={{ color: '#FFB020' }}
              />
              <Bar dataKey="total_revenue" fill="#FFB020" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        
        <div className="card h-96">
          <h2 className="text-lg font-semibold mb-6">Volume Trend (14 days)</h2>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={kpis}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1F2937" vertical={false} />
              <XAxis dataKey="day" tickFormatter={t => new Date(t).getDate().toString()} stroke="#6B7280" />
              <YAxis stroke="#6B7280" />
              <Tooltip 
                contentStyle={{ backgroundColor: '#111827', borderColor: '#1F2937' }}
                itemStyle={{ color: '#2DD4BF' }}
              />
              <Bar dataKey="total_shipments" fill="#2DD4BF" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}

function Package(props: any) {
  return <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m7.5 4.27 9 5.15"/><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/></svg>
}
