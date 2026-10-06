'use client'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import Link from 'next/link'
import { toast } from 'sonner'
import { Truck, ArrowLeft, CheckCircle } from 'lucide-react'
import { resetSchema, type ResetForm } from '@/lib/schemas/auth.schema'
import { createClient } from '@/lib/supabase/client'

export default function ResetPage() {
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)
  const { register, handleSubmit, formState: { errors } } = useForm<ResetForm>({
    resolver: zodResolver(resetSchema),
  })

  async function onSubmit(data: ResetForm) {
    setLoading(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.auth.resetPasswordForEmail(data.email, {
        redirectTo: `${window.location.origin}/reset/confirm`,
      })
      if (error) throw error
      setSent(true)
    } catch (e: unknown) {
      toast.error((e as Error).message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#0B1020] flex items-center justify-center p-8">
      <div className="w-full max-w-md">
        <div className="flex items-center gap-3 mb-8">
          <div className="w-8 h-8 bg-[#FFB020] rounded-lg flex items-center justify-center">
            <Truck size={16} className="text-[#0B1020]" />
          </div>
          <span className="font-display font-bold text-lg text-[#F4F1EA]">RTLTS</span>
        </div>

        {sent ? (
          <div className="text-center">
            <CheckCircle className="text-[#2DD4BF] mx-auto mb-4" size={48} />
            <h2 className="font-display text-xl font-bold text-[#F4F1EA] mb-2">Reset email sent</h2>
            <p className="text-gray-400 text-sm mb-6">Check your inbox for the reset link.</p>
            <Link href="/login" className="btn-secondary inline-flex gap-2">
              <ArrowLeft size={16} /> Back to login
            </Link>
          </div>
        ) : (
          <>
            <h2 className="font-display text-2xl font-bold text-[#F4F1EA] mb-1">Reset password</h2>
            <p className="text-gray-400 text-sm mb-8">
              Enter your email and we&apos;ll send a reset link.
            </p>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1.5">Email</label>
                <input {...register('email')} type="email" className="input-base" placeholder="you@company.com" />
                {errors.email && <p className="text-xs text-red-400 mt-1">{errors.email.message}</p>}
              </div>
              <button type="submit" disabled={loading} className="btn-primary w-full">
                {loading ? 'Sending...' : 'Send reset link'}
              </button>
            </form>
            <div className="text-center mt-6">
              <Link href="/login" className="text-sm text-gray-400 hover:text-[#F4F1EA] inline-flex items-center gap-1">
                <ArrowLeft size={14} /> Back to login
              </Link>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
