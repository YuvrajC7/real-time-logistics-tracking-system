/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: { allowedOrigins: ['localhost:3000'] },
  },
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'vmptffyvknyoybdoqfdq.supabase.co' },
      { protocol: 'https', hostname: 'lh3.googleusercontent.com' },
    ],
  },
  webpack: (config) => {
    // Allow three.js
    config.externals.push({ canvas: 'canvas' })
    return config
  },
}
export default nextConfig
