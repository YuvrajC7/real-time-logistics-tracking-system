import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

async function simulate() {
  console.log('Starting Node Location Simulator...')
  
  // Fetch ongoing trips
  const { data: trips, error } = await supabase
    .from('trips')
    .select('trip_id, vehicle_id')
    .eq('status', 'ONGOING')

  if (error || !trips) {
    console.error('Error fetching trips:', error)
    process.exit(1)
  }

  console.log(`Found ${trips.length} active trips. Simulating movement...`)

  // Random movement logic
  setInterval(async () => {
    for (const trip of trips) {
      // For simulation, randomly jitter near central India
      const lat = 20.0 + (Math.random() * 5)
      const lng = 75.0 + (Math.random() * 5)
      const speed = 40 + Math.random() * 40 // 40-80 kmph
      const heading = Math.random() * 360

      const { error: pingErr } = await supabase.rpc('record_location', {
        p_vehicle_id: trip.vehicle_id,
        p_trip_id: trip.trip_id,
        p_lat: lat,
        p_lng: lng,
        p_speed: speed,
        p_heading: heading
      })

      if (pingErr) console.error(`Ping failed for vehicle ${trip.vehicle_id}:`, pingErr.message)
      else console.log(`Ping OK: vehicle ${trip.vehicle_id} @ ${lat.toFixed(4)}, ${lng.toFixed(4)}`)
    }
  }, 3000) // 3 seconds
}

simulate()
