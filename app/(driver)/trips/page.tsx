'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Truck, CheckCircle } from 'lucide-react'
import { toast } from 'sonner'
import { StatusBadge } from '@/components/ui/StatusBadge'

export default function DriverTrips() {
  const [trips, setTrips] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadTrips() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data } = await supabase
        .from('trips')
        .select(`
          *,
          route:routes(name, distance_km),
          vehicle:vehicles(plate_no),
          shipments:trip_shipments(shipment:shipments(tracking_no, status, dest_addr_id))
        `)
        .eq('driver_id', user.id)
        .in('status', ['PLANNED', 'ONGOING'])
        
      setTrips(data || [])
      setLoading(false)
    }
    loadTrips()
  }, [])

  const startTrip = async (tripId: string) => {
    const supabase = createClient()
    const { error } = await supabase
      .from('trips')
      .update({ status: 'ONGOING', actual_start: new Date().toISOString() })
      .eq('trip_id', tripId)
    
    if (error) toast.error('Failed to start trip')
    else {
      toast.success('Trip started!')
      setTrips(trips.map(t => t.trip_id === tripId ? { ...t, status: 'ONGOING' } : t))
    }
  }

  if (loading) return <div>Loading route sheet...</div>

  return (
    <div className="space-y-6 animate-fade-in pb-20">
      <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">Today's Runs</h1>
      
      {trips.length === 0 ? (
        <div className="text-center py-12 text-gray-500">No active trips assigned.</div>
      ) : trips.map(trip => (
        <div key={trip.trip_id} className="card p-5 space-y-4">
          <div className="flex justify-between items-start border-b border-[#1F2937] pb-3">
            <div>
              <h2 className="font-bold text-lg text-[#F4F1EA]">{trip.route?.name || 'Local Route'}</h2>
              <p className="text-sm text-gray-400 flex items-center gap-2 mt-1">
                <Truck size={14} /> {trip.vehicle?.plate_no}
              </p>
            </div>
            <StatusBadge status={trip.status === 'ONGOING' ? 'IN_TRANSIT' : 'CREATED'} />
          </div>
          
          <div className="text-sm text-gray-400">
            <p><strong>{trip.shipments?.length || 0}</strong> Shipments to deliver</p>
            <p>Distance: {trip.route?.distance_km} km</p>
          </div>

          {trip.status === 'PLANNED' ? (
            <button onClick={() => startTrip(trip.trip_id)} className="btn-primary w-full py-3 text-lg">
              Start Trip
            </button>
          ) : (
            <div className="bg-[#2DD4BF]/10 text-[#2DD4BF] text-center py-3 rounded-lg font-semibold flex items-center justify-center gap-2">
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#2DD4BF] opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-[#2DD4BF]"></span>
              </span>
              Trip in Progress
            </div>
          )}
        </div>
      ))}
    </div>
  )
}
