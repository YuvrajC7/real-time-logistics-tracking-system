'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { newShipmentSchema, type NewShipmentForm } from '@/lib/schemas/shipment.schema'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'sonner'

export default function NewShipmentPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const { register, handleSubmit, formState: { errors } } = useForm<NewShipmentForm>({
    resolver: zodResolver(newShipmentSchema),
    defaultValues: {
      origin: { country: 'India' },
      destination: { country: 'India' },
      packages: [{ description: '', weight_kg: 1, category: 'General', is_fragile: false }],
      service_type: 'STANDARD',
    }
  })

  async function onSubmit(data: NewShipmentForm) {
    setLoading(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('Not authenticated')

      // 1. Insert Addresses
      const { data: orgAddr, error: e1 } = await supabase.from('addresses').insert(data.origin).select('address_id').single()
      if (e1) throw e1
      
      const { data: dstAddr, error: e2 } = await supabase.from('addresses').insert(data.destination).select('address_id').single()
      if (e2) throw e2

      // 2. Compute charge (Mock calculation)
      const charge = data.service_type === 'EXPRESS' ? 500 : data.service_type === 'SAME_DAY' ? 1000 : 200

      // 3. Insert Shipment (Trigger will generate tracking_no)
      const { data: shipment, error: e3 } = await supabase.from('shipments').insert({
        sender_id: user.id,
        receiver_name: data.receiver_name,
        receiver_phone: data.receiver_phone,
        origin_addr_id: orgAddr.address_id,
        dest_addr_id: dstAddr.address_id,
        service_type: data.service_type,
        special_notes: data.special_notes,
        charge,
        eta: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
      }).select('shipment_id, tracking_no').single()
      if (e3) throw e3

      // 4. Insert Packages
      const pkgs = data.packages.map(p => ({ ...p, shipment_id: shipment.shipment_id }))
      const { error: e4 } = await supabase.from('packages').insert(pkgs)
      if (e4) throw e4

      toast.success(`Shipment created! Tracking: ${shipment.tracking_no}`)
      router.push('/customer/shipments')
    } catch (e: any) {
      toast.error(e.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-3xl animate-fade-in space-y-6">
      <div>
        <h1 className="text-2xl font-display font-bold text-[#F4F1EA]">Create Shipment</h1>
        <p className="text-gray-400 mt-1">Book a new parcel delivery.</p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
        
        {/* Addresses */}
        <div className="grid md:grid-cols-2 gap-6">
          <div className="card space-y-4">
            <h2 className="font-semibold text-lg border-b border-[#1F2937] pb-2">Pickup Address</h2>
            <div>
              <label className="block text-sm mb-1 text-gray-400">Line 1</label>
              <input {...register('origin.line1')} className="input-base" />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm mb-1 text-gray-400">City</label>
                <input {...register('origin.city')} className="input-base" />
              </div>
              <div>
                <label className="block text-sm mb-1 text-gray-400">PIN Code</label>
                <input {...register('origin.postal_code')} className="input-base" />
              </div>
            </div>
            <div>
              <label className="block text-sm mb-1 text-gray-400">State</label>
              <input {...register('origin.state')} className="input-base" />
            </div>
          </div>

          <div className="card space-y-4">
            <h2 className="font-semibold text-lg border-b border-[#1F2937] pb-2">Delivery Address</h2>
            <div>
              <label className="block text-sm mb-1 text-gray-400">Receiver Name</label>
              <input {...register('receiver_name')} className="input-base" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-gray-400">Receiver Phone</label>
              <input {...register('receiver_phone')} className="input-base" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-gray-400">Line 1</label>
              <input {...register('destination.line1')} className="input-base" />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm mb-1 text-gray-400">City</label>
                <input {...register('destination.city')} className="input-base" />
              </div>
              <div>
                <label className="block text-sm mb-1 text-gray-400">PIN Code</label>
                <input {...register('destination.postal_code')} className="input-base" />
              </div>
            </div>
            <div>
              <label className="block text-sm mb-1 text-gray-400">State</label>
              <input {...register('destination.state')} className="input-base" />
            </div>
          </div>
        </div>

        {/* Package & Service */}
        <div className="card space-y-6">
          <h2 className="font-semibold text-lg border-b border-[#1F2937] pb-2">Package Details</h2>
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm mb-1 text-gray-400">Description</label>
              <input {...register('packages.0.description')} className="input-base" placeholder="e.g., Electronics, Documents" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-gray-400">Weight (kg)</label>
              <input type="number" step="0.1" {...register('packages.0.weight_kg', { valueAsNumber: true })} className="input-base" />
            </div>
          </div>
          
          <div className="space-y-4 pt-4 border-t border-[#1F2937]">
            <h3 className="text-sm font-medium text-gray-300">Service Level</h3>
            <div className="flex gap-4">
              {['STANDARD', 'EXPRESS', 'SAME_DAY'].map(srv => (
                <label key={srv} className="flex items-center gap-2 cursor-pointer">
                  <input type="radio" value={srv} {...register('service_type')} className="accent-amber-500" />
                  <span className="text-sm capitalize">{srv.replace('_', ' ').toLowerCase()}</span>
                </label>
              ))}
            </div>
          </div>
        </div>

        <button type="submit" disabled={loading} className="btn-primary w-full py-4 text-lg">
          {loading ? 'Processing...' : 'Book Shipment'}
        </button>
      </form>
    </div>
  )
}
