'use client'
import { useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { ShipmentStatus } from '@/lib/supabase/types'

// Hook: subscribe to tracking events for a shipment
export function useShipmentRealtime(
  trackingNo: string,
  onEvent: (status: ShipmentStatus, note: string | null) => void
) {
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`shipment:${trackingNo}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'tracking_events',
        },
        async (payload) => {
          const shipmentId = payload.new.shipment_id
          // Verify it's this shipment
          const { data } = await supabase
            .from('shipments')
            .select('tracking_no')
            .eq('shipment_id', shipmentId)
            .single()
          if (data?.tracking_no === trackingNo) {
            onEvent(payload.new.status, payload.new.note)
          }
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [trackingNo, onEvent])
}

// Hook: subscribe to vehicle location pings
export function useVehicleLocation(
  vehicleId: string | null,
  onPing: (lat: number, lng: number, speed: number | null, heading: number | null) => void
) {
  useEffect(() => {
    if (!vehicleId) return
    const supabase = createClient()
    const channel = supabase
      .channel(`vehicle:${vehicleId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'location_pings',
          filter: `vehicle_id=eq.${vehicleId}`,
        },
        (payload) => {
          onPing(payload.new.lat, payload.new.lng, payload.new.speed_kmph, payload.new.heading)
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [vehicleId, onPing])
}

// Hook: subscribe to notifications for current user
export function useNotifications(
  profileId: string | null,
  onNotification: (message: string, shipmentId: string | null) => void
) {
  useEffect(() => {
    if (!profileId) return
    const supabase = createClient()
    const channel = supabase
      .channel(`notifications:${profileId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `profile_id=eq.${profileId}`,
        },
        (payload) => {
          onNotification(payload.new.message, payload.new.shipment_id)
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [profileId, onNotification])
}
