'use client'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { Truck, Eye, EyeOff, ArrowRight, CheckCircle } from 'lucide-react'
import { signupSchema, type SignupForm } from '@/lib/schemas/auth.schema'
import { createClient } from '@/lib/supabase/client'

export default function SignupPage() {
  const router = useRouter()
  const [showPw, setShowPw] = useState(false)
  const [loading, setLoading] = useState(false)
  const [done, setDone] = useState(false)

  const { register, handleSubmit, formState: { errors } } = useForm<SignupForm>({
    resolver: zodResolver(signupSchema),
  })

  async function onSubmit(data: SignupForm) {
    setLoading(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.auth.signUp({
        email: data.email,
        password: data.password,
        options: {
          data: { full_name: data.full_name, role: 'customer' },
        },
      })
      if (error) throw error
      setDone(true)
    } catch (e: unknown) {
      toast.error((e as Error).message || 'Signup failed')
    } finally {
      setLoading(false)
    }
  }

  if (done) {
    return (
      <div className="min-h-screen bg-[#0B1020] flex items-center justify-center p-8">
        <div className="text-center max-w-sm">
          <CheckCircle className="text-[#2DD4BF] mx-auto mb-4" size={48} />
          <h2 className="font-display text-2xl font-bold text-[#F4F1EA] mb-2">Check your email</h2>
          <p className="text-gray-400 text-sm">
            We sent a confirmation link. Click it to activate your account, then sign in.
          </p>
          <Link href="/login" className="btn-primary mt-6 inline-flex">Go to Login</Link>
        </div>
      </div>
    )
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

        <h2 className="font-display text-2xl font-bold text-[#F4F1EA] mb-1">Create account</h2>
        <p className="text-gray-400 text-sm mb-8">Start tracking your shipments today.</p>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1.5">Full Name</label>
            <input {...register('full_name')} className="input-base" placeholder="Arun Kumar" />
            {errors.full_name && <p className="text-xs text-red-400 mt-1">{errors.full_name.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1.5">Email</label>
            <input {...register('email')} type="email" className="input-base" placeholder="you@company.com" />
            {errors.email && <p className="text-xs text-red-400 mt-1">{errors.email.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1.5">Password</label>
            <div className="relative">
              <input
                {...register('password')}
                type={showPw ? 'text' : 'password'}
                className="input-base pr-10"
                placeholder="Min 8 characters"
              />
              <button type="button" onClick={() => setShowPw(!showPw)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300">
                {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {errors.password && <p className="text-xs text-red-400 mt-1">{errors.password.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1.5">Confirm Password</label>
            <input {...register('confirm')} type="password" className="input-base" placeholder="Repeat password" />
            {errors.confirm && <p className="text-xs text-red-400 mt-1">{errors.confirm.message}</p>}
          </div>
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Creating account...' : 'Create Account'}
            {!loading && <ArrowRight size={16} />}
          </button>
        </form>

        <p className="text-center text-sm text-gray-500 mt-6">
          Already have an account?{' '}
          <Link href="/login" className="text-[#FFB020] hover:underline">Sign in</Link>
        </p>
      </div>
    </div>
  )
}
