'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useNotifications } from '@/lib/hooks/useRealtime'
import { Bell, CheckCircle } from 'lucide-react'
import { formatDate } from '@/lib/utils'

export default function NotificationsPage() {
  const [notifs, setNotifs] = useState<any[]>([])
  const [userId, setUserId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      setUserId(user.id)
      
      const { data } = await supabase
        .from('notifications')
        .select('*')
        .eq('profile_id', user.id)
        .order('created_at', { ascending: false })
      setNotifs(data || [])
      setLoading(false)
    }
    load()
  }, [])

  useNotifications(userId, (msg, sid) => {
    setNotifs(prev => [{ notification_id: Date.now().toString(), message: msg, shipment_id: sid, created_at: new Date().toISOString(), is_read: false }, ...prev])
  })

  const markAllRead = async () => {
    const supabase = createClient()
    await supabase.from('notifications').update({ is_read: true }).eq('profile_id', userId)
    setNotifs(n => n.map(x => ({ ...x, is_read: true })))
  }

  if (loading) return <div>Loading...</div>

  return (
    <div className="max-w-3xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-display font-bold text-[#F4F1EA] flex items-center gap-2">
          <Bell size={24} className="text-[#FFB020]" /> Notifications
        </h1>
        <button onClick={markAllRead} className="btn-secondary py-1.5 text-xs">Mark all read</button>
      </div>

      <div className="space-y-4">
        {notifs.length === 0 ? (
          <div className="text-center py-12 text-gray-500">No new notifications</div>
        ) : (
          notifs.map(n => (
            <div key={n.notification_id} className={`p-4 rounded-xl border ${n.is_read ? 'bg-[#111827] border-[#1F2937]' : 'bg-[#FFB020]/10 border-[#FFB020]/30'}`}>
              <div className="flex justify-between items-start">
                <p className="text-sm text-[#F4F1EA]">{n.message}</p>
                <span className="text-xs text-gray-500 font-mono">{formatDate(n.created_at)}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
