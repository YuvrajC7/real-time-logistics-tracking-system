import { z } from 'zod'

export const addressSchema = z.object({
  line1:       z.string().min(5, 'Address line 1 is required'),
  line2:       z.string().optional(),
  city:        z.string().min(2, 'City is required'),
  state:       z.string().min(2, 'State is required'),
  postal_code: z.string().min(6, 'Valid PIN code required').max(6),
  country:     z.string().default('India'),
  lat:         z.number().min(-90).max(90).optional(),
  lng:         z.number().min(-180).max(180).optional(),
})

export const packageSchema = z.object({
  description: z.string().min(3, 'Description required'),
  weight_kg:   z.number().positive('Weight must be positive'),
  length_cm:   z.number().positive().optional(),
  width_cm:    z.number().positive().optional(),
  height_cm:   z.number().positive().optional(),
  category:    z.string().default('General'),
  is_fragile:  z.boolean().default(false),
})

export const newShipmentSchema = z.object({
  // Step 1: Addresses
  origin:       addressSchema,
  destination:  addressSchema,
  // Step 2: Package
  receiver_name:  z.string().min(2, 'Receiver name required'),
  receiver_phone: z.string().min(10, 'Valid phone number required'),
  packages:       z.array(packageSchema).min(1, 'At least one package required'),
  special_notes:  z.string().optional(),
  // Step 3: Service
  service_type: z.enum(['STANDARD', 'EXPRESS', 'SAME_DAY']),
})

export type NewShipmentForm = z.infer<typeof newShipmentSchema>
export type AddressForm = z.infer<typeof addressSchema>
export type PackageForm = z.infer<typeof packageSchema>
