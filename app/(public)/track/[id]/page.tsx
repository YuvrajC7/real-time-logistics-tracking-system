'use client'
import { useState, useEffect } from 'react'
import { useParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Navbar } from '@/components/layout/Navbar'
import { Timeline } from '@/components/ui/Timeline'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { Truck, MapPin, Package, Clock, AlertCircle } from 'lucide-react'
import { useShipmentRealtime } from '@/lib/hooks/useRealtime'
import { formatDate } from '@/lib/utils'

export default function PublicTrackingPage() {
  const params = useParams()
  const trackingNo = params.id as string
  const [data, setData] = useState<any>(null)
  const [events, setEvents] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchTracking = async () => {
    try {
      setLoading(true)
      const supabase = createClient()
      
      // Call public_track RPC
      const { data: trackData, error: trackErr } = await supabase
        .rpc('public_track', { p_tracking_no: trackingNo })
      
      if (trackErr) throw trackErr
      if (!trackData || trackData.length === 0) {
        throw new Error('Shipment not found or unauthorized')
      }
      
      setData(trackData[0])

      // Get events
      const { data: evtData, error: evtErr } = await supabase
        .rpc('get_shipment_events', { p_tracking_no: trackingNo })
        
      if (evtErr) throw evtErr
      setEvents(evtData || [])

    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (trackingNo) fetchTracking()
  }, [trackingNo])

  // Realtime updates
  useShipmentRealtime(trackingNo, (status, note) => {
    // If we get an event, just re-fetch to ensure consistency
    fetchTracking()
  })

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0B1020] flex items-center justify-center">
        <div className="animate-spin-slow w-12 h-12 border-4 border-[#1F2937] border-t-[#FFB020] rounded-full" />
      </div>
    )
  }

  if (error || !data) {
    return (
      <div className="min-h-screen bg-[#0B1020]">
        <Navbar />
        <div className="max-w-2xl mx-auto pt-32 px-6 text-center">
          <AlertCircle className="w-16 h-16 text-red-400 mx-auto mb-6" />
          <h1 className="text-3xl font-display font-bold text-[#F4F1EA] mb-4">Tracking not found</h1>
          <p className="text-gray-400 mb-8">We couldn't find any information for tracking number <span className="font-mono text-[#F4F1EA] bg-white/5 px-2 py-1 rounded">{trackingNo}</span>. Please check the number and try again.</p>
          <button onClick={() => window.history.back()} className="btn-secondary">Go Back</button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#0B1020]">
      <Navbar />
      <main className="max-w-4xl mx-auto pt-32 px-6 pb-20">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6 mb-10">
          <div>
            <h1 className="text-3xl font-display font-bold text-[#F4F1EA] mb-2">Track Shipment</h1>
            <p className="text-lg font-mono text-gray-400">ID: {data.tracking_no}</p>
          </div>
          <StatusBadge status={data.status} size="lg" />
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {/* Main Info */}
          <div className="md:col-span-2 space-y-6">
            <div className="card grid grid-cols-2 gap-8">
              <div>
                <p className="text-sm text-gray-500 font-medium mb-1 flex items-center gap-2"><MapPin size={14}/> Origin</p>
                <p className="text-lg font-semibold text-[#F4F1EA]">{data.origin_city}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 font-medium mb-1 flex items-center gap-2"><MapPin size={14}/> Destination</p>
                <p className="text-lg font-semibold text-[#F4F1EA]">{data.dest_city}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 font-medium mb-1 flex items-center gap-2"><Clock size={14}/> Estimated Delivery</p>
                <p className="text-lg font-semibold text-[#F4F1EA]">
                  {data.eta ? formatDate(data.eta) : 'Calculating...'}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 font-medium mb-1 flex items-center gap-2"><Package size={14}/> Service Level</p>
                <p className="text-lg font-semibold text-[#F4F1EA] capitalize">{data.service_type.replace('_', ' ')}</p>
              </div>
            </div>

            {/* Timeline */}
            <div className="card">
              <h2 className="text-xl font-display font-bold text-[#F4F1EA] mb-8">Tracking History</h2>
              <Timeline events={events} />
            </div>
          </div>

          {/* Sidebar Info */}
          <div className="space-y-6">
            <div className="card">
              <h3 className="font-semibold text-[#F4F1EA] mb-4">Recipient</h3>
              <p className="text-gray-400">{data.receiver_name}</p>
            </div>
            <div className="p-6 rounded-xl bg-gradient-to-br from-[#2DD4BF]/10 to-transparent border border-[#2DD4BF]/20">
              <Truck className="text-[#2DD4BF] mb-4" size={24} />
              <h3 className="font-bold text-[#F4F1EA] mb-2">Need live map access?</h3>
              <p className="text-sm text-gray-400">Sign in to your customer account to view live vehicle telemetry and manage notifications.</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
