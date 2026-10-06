// Auto-generated types matching the database schema
// Run: npx supabase gen types typescript --project-id vmptffyvknyoybdoqfdq > lib/supabase/types.ts
// After running migrations, regenerate this file.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type UserRole = 'admin' | 'dispatcher' | 'driver' | 'customer'
export type ShipmentStatus =
  | 'CREATED'
  | 'PICKED_UP'
  | 'IN_TRANSIT'
  | 'AT_HUB'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'FAILED_ATTEMPT'
  | 'RETURNED'
  | 'CANCELLED'
export type ServiceType = 'STANDARD' | 'EXPRESS' | 'SAME_DAY'
export type VehicleStatus = 'AVAILABLE' | 'ON_TRIP' | 'MAINTENANCE' | 'RETIRED'
export type TripStatus = 'PLANNED' | 'ONGOING' | 'COMPLETED' | 'CANCELLED'
export type InvoiceStatus = 'PENDING' | 'PAID' | 'CANCELLED'
export type HubStatus = 'ACTIVE' | 'INACTIVE' | 'MAINTENANCE'

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          profile_id: string
          full_name: string
          email: string
          phone: string | null
          role: UserRole
          avatar_url: string | null
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['profiles']['Row'], 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>
      }
      customers: {
        Row: {
          customer_id: string
          company_name: string | null
          customer_type: 'INDIVIDUAL' | 'BUSINESS'
        }
        Insert: Database['public']['Tables']['customers']['Row']
        Update: Partial<Database['public']['Tables']['customers']['Row']>
      }
      drivers: {
        Row: {
          driver_id: string
          license_no: string
          license_expiry: string
          availability: boolean
          rating: number | null
          total_deliveries: number
          on_time_count: number
        }
        Insert: Omit<Database['public']['Tables']['drivers']['Row'], 'total_deliveries' | 'on_time_count'>
        Update: Partial<Database['public']['Tables']['drivers']['Row']>
      }
      addresses: {
        Row: {
          address_id: string
          line1: string
          line2: string | null
          city: string
          state: string
          postal_code: string
          country: string
          lat: number | null
          lng: number | null
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['addresses']['Row'], 'address_id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['addresses']['Insert']>
      }
      hubs: {
        Row: {
          hub_id: string
          name: string
          address_id: string
          capacity: number
          status: HubStatus
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['hubs']['Row'], 'hub_id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['hubs']['Insert']>
      }
      vehicles: {
        Row: {
          vehicle_id: string
          plate_no: string
          type: string
          capacity_kg: number
          status: VehicleStatus
          home_hub_id: string | null
          model: string | null
          year: number | null
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['vehicles']['Row'], 'vehicle_id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['vehicles']['Insert']>
      }
      shipments: {
        Row: {
          shipment_id: string
          tracking_no: string
          sender_id: string
          receiver_name: string
          receiver_phone: string
          origin_addr_id: string
          dest_addr_id: string
          service_type: ServiceType
          status: ShipmentStatus
          charge: number | null
          eta: string | null
          special_notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['shipments']['Row'], 'shipment_id' | 'tracking_no' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['shipments']['Insert']>
      }
      packages: {
        Row: {
          package_id: string
          shipment_id: string
          description: string
          weight_kg: number
          length_cm: number | null
          width_cm: number | null
          height_cm: number | null
          category: string
          is_fragile: boolean
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['packages']['Row'], 'package_id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['packages']['Insert']>
      }
      trips: {
        Row: {
          trip_id: string
          driver_id: string
          vehicle_id: string
          route_id: string | null
          from_hub_id: string | null
          to_hub_id: string | null
          status: TripStatus
          planned_start: string
          actual_start: string | null
          actual_end: string | null
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['trips']['Row'], 'trip_id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['trips']['Insert']>
      }
      tracking_events: {
        Row: {
          event_id: string
          shipment_id: string
          status: ShipmentStatus
          hub_id: string | null
          note: string | null
          created_by: string | null
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['tracking_events']['Row'], 'event_id' | 'created_at'>
        Update: never
      }
      location_pings: {
        Row: {
          ping_id: string
          vehicle_id: string
          trip_id: string | null
          lat: number
          lng: number
          speed_kmph: number | null
          heading: number | null
          recorded_at: string
        }
        Insert: Omit<Database['public']['Tables']['location_pings']['Row'], 'ping_id' | 'recorded_at'>
        Update: never
      }
      notifications: {
        Row: {
          notification_id: string
          profile_id: string
          shipment_id: string | null
          message: string
          is_read: boolean
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['notifications']['Row'], 'notification_id' | 'created_at'>
        Update: Partial<Pick<Database['public']['Tables']['notifications']['Row'], 'is_read'>>
      }
      invoices: {
        Row: {
          invoice_id: string
          shipment_id: string
          amount: number
          tax: number
          status: InvoiceStatus
          issued_at: string
        }
        Insert: Omit<Database['public']['Tables']['invoices']['Row'], 'invoice_id' | 'issued_at'>
        Update: Partial<Database['public']['Tables']['invoices']['Insert']>
      }
      delivery_proofs: {
        Row: {
          proof_id: string
          shipment_id: string
          photo_url: string
          recipient_name: string
          otp_verified: boolean
          signed_at: string
        }
        Insert: Omit<Database['public']['Tables']['delivery_proofs']['Row'], 'proof_id' | 'signed_at'>
        Update: never
      }
      routes: {
        Row: {
          route_id: string
          name: string
          origin_hub_id: string
          destination_hub_id: string
          distance_km: number
          is_active: boolean
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['routes']['Row'], 'route_id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['routes']['Insert']>
      }
      route_stops: {
        Row: {
          route_id: string
          stop_no: number
          hub_id: string
          expected_minutes: number
        }
        Insert: Database['public']['Tables']['route_stops']['Row']
        Update: Partial<Database['public']['Tables']['route_stops']['Row']>
      }
      pricing_rules: {
        Row: {
          service: ServiceType
          base_charge: number
          rate_per_kg: number
          rate_per_km: number
          gst_rate: number
        }
        Insert: Database['public']['Tables']['pricing_rules']['Row']
        Update: Partial<Database['public']['Tables']['pricing_rules']['Row']>
      }
    }
    Views: {
      v_active_shipments: {
        Row: {
          shipment_id: string
          tracking_no: string
          status: ShipmentStatus
          service_type: ServiceType
          charge: number | null
          eta: string | null
          created_at: string
          sender_name: string
          sender_email: string
          sender_phone: string | null
          receiver_name: string
          receiver_phone: string
          origin_city: string
          origin_state: string
          origin_line1: string
          dest_city: string
          dest_state: string
          dest_line1: string
        }
      }
      v_driver_performance: {
        Row: {
          driver_id: string
          full_name: string
          rating: number | null
          total_deliveries: number
          on_time_count: number
          on_time_rate_pct: number
          performance_rank: number
        }
      }
      v_latest_vehicle_location: {
        Row: {
          vehicle_id: string
          plate_no: string
          vehicle_type: string
          vehicle_status: VehicleStatus
          home_hub_name: string | null
          lat: number
          lng: number
          speed_kmph: number | null
          heading: number | null
          trip_id: string | null
          recorded_at: string
          trip_status: TripStatus | null
          driver_name: string | null
        }
      }
    }
    Functions: {
      public_track: {
        Args: { p_tracking_no: string }
        Returns: Array<{
          tracking_no: string
          status: ShipmentStatus
          receiver_name: string
          service_type: ServiceType
          eta: string | null
          created_at: string
          origin_city: string
          dest_city: string
        }>
      }
      calculate_charge: {
        Args: { p_weight: number; p_distance_km: number; p_service: ServiceType }
        Returns: number
      }
      assign_shipment_to_trip: {
        Args: { p_shipment_id: string; p_trip_id: string }
        Returns: Json
      }
      update_shipment_status: {
        Args: { p_shipment_id: string; p_new_status: ShipmentStatus; p_hub_id?: string; p_note?: string }
        Returns: Json
      }
      record_location: {
        Args: { p_vehicle_id: string; p_lat: number; p_lng: number; p_speed?: number; p_heading?: number; p_trip_id?: string }
        Returns: Json
      }
      get_dispatcher_stats: {
        Args: Record<string, never>
        Returns: Json
      }
      get_shipment_events: {
        Args: { p_tracking_no: string }
        Returns: Array<{
          status: ShipmentStatus
          hub_name: string | null
          note: string | null
          created_at: string
        }>
      }
    }
    Enums: {
      user_role: UserRole
      shipment_status: ShipmentStatus
      service_type: ServiceType
      vehicle_status: VehicleStatus
      trip_status: TripStatus
      invoice_status: InvoiceStatus
      hub_status: HubStatus
    }
  }
}
