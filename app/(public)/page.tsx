'use client'
import { useEffect, useRef } from 'react'
import { Navbar } from '@/components/layout/Navbar'
import { Globe } from '@/components/3d/Globe'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger'
import Lenis from 'lenis'
import Link from 'next/link'
import { ArrowRight, Map, Zap, ShieldCheck } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useRouter } from 'next/navigation'

gsap.registerPlugin(ScrollTrigger)

export default function LandingPage() {
  const router = useRouter()
  const heroRef = useRef<HTMLDivElement>(null)
  const featuresRef = useRef<HTMLDivElement>(null)

  const { register, handleSubmit } = useForm<{ tracking_no: string }>()

  useEffect(() => {
    // Smooth scrolling
    const lenis = new Lenis({ duration: 1.2, easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)) })
    function raf(time: number) {
      lenis.raf(time)
      requestAnimationFrame(raf)
    }
    requestAnimationFrame(raf)

    // GSAP animations
    if (heroRef.current) {
      gsap.fromTo(heroRef.current.children, 
        { y: 50, opacity: 0 },
        { y: 0, opacity: 1, duration: 1, stagger: 0.2, ease: 'power3.out', delay: 0.2 }
      )
    }

    if (featuresRef.current) {
      gsap.fromTo(featuresRef.current.children,
        { y: 50, opacity: 0 },
        {
          y: 0, opacity: 1, duration: 0.8, stagger: 0.2, ease: 'power2.out',
          scrollTrigger: { trigger: featuresRef.current, start: 'top 80%' }
        }
      )
    }

    return () => lenis.destroy()
  }, [])

  const onTrack = (data: { tracking_no: string }) => {
    if (data.tracking_no) router.push(`/track/${data.tracking_no}`)
  }

  return (
    <div className="min-h-screen bg-[#0B1020] text-[#F4F1EA] overflow-hidden">
      <Navbar />
      
      {/* Hero Section */}
      <section className="relative w-full h-screen flex flex-col items-center justify-center text-center px-6">
        <Globe />
        <div ref={heroRef} className="z-10 max-w-4xl mt-20">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-sm font-medium text-[#2DD4BF] mb-8">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#2DD4BF] opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-[#2DD4BF]"></span>
            </span>
            Live operations system active
          </div>
          
          <h1 className="text-5xl md:text-7xl font-display font-bold leading-tight tracking-tight mb-6">
            Move at the speed of <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#FFB020] to-[#2DD4BF]">certainty.</span>
          </h1>
          
          <p className="text-lg md:text-xl text-gray-400 mb-10 max-w-2xl mx-auto">
            The intelligent control tower for your supply chain. Track fleets in real-time, optimize routes dynamically, and deliver trust.
          </p>

          {/* Quick Track Input */}
          <form onSubmit={handleSubmit(onTrack)} className="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto mb-12">
            <input 
              {...register('tracking_no')} 
              placeholder="Enter tracking number (RTL-...)" 
              className="flex-1 px-4 py-3 bg-[#111827]/80 backdrop-blur-sm border border-[#1F2937] rounded-xl focus:outline-none focus:border-[#FFB020] transition-colors"
            />
            <button type="submit" className="btn-primary py-3 px-6 whitespace-nowrap">
              Track Shipment
            </button>
          </form>

          <div className="flex flex-wrap items-center justify-center gap-8 text-sm font-medium text-gray-500">
            <span>✓ 99.9% Uptime</span>
            <span>✓ Millisecond Latency</span>
            <span>✓ Pan-India Coverage</span>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-32 px-6 bg-[#0B1020] relative">
        <div className="absolute inset-0 bg-grid opacity-30 pointer-events-none" />
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-20">
            <h2 className="text-3xl md:text-5xl font-display font-bold mb-6">Built for scale, designed for speed</h2>
            <p className="text-gray-400 max-w-2xl mx-auto">Everything you need to run a modern logistics network, from first mile dispatch to final mile delivery.</p>
          </div>

          <div ref={featuresRef} className="grid md:grid-cols-3 gap-8">
            {[
              { 
                icon: Map, 
                title: 'Live Telemetry', 
                desc: 'Watch your entire fleet move in real-time. Sub-second location updates directly to your dashboard.' 
              },
              { 
                icon: Zap, 
                title: 'Dynamic Routing', 
                desc: 'Instantly adapt to traffic and delays. Our engine recalculates ETAs and optimizes stops on the fly.' 
              },
              { 
                icon: ShieldCheck, 
                title: 'Immutable Audit', 
                desc: 'Every scan, handover, and delivery is cryptographically logged. Complete dispute resolution.' 
              }
            ].map((feature, i) => (
              <div key={i} className="p-8 rounded-2xl bg-[#111827] border border-[#1F2937] hover:border-[#FFB020]/50 transition-colors">
                <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center text-[#FFB020] mb-6">
                  <feature.icon size={24} />
                </div>
                <h3 className="text-xl font-bold font-display mb-3">{feature.title}</h3>
                <p className="text-gray-400 leading-relaxed">{feature.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-32 px-6 text-center border-t border-[#1F2937]">
        <h2 className="text-3xl md:text-5xl font-display font-bold mb-8">Ready to upgrade your logistics?</h2>
        <Link href="/signup" className="btn-primary px-8 py-4 text-lg">
          Create Free Account <ArrowRight className="ml-2" />
        </Link>
      </section>
    </div>
  )
}
