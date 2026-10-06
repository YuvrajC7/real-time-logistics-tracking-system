'use client'
import { useRef, useEffect } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, Line } from '@react-three/drei'
import * as THREE from 'three'

function GlobeLines() {
  const groupRef = useRef<THREE.Group>(null)

  useFrame((state) => {
    if (groupRef.current) {
      groupRef.current.rotation.y = state.clock.elapsedTime * 0.1
    }
  })

  // Basic representation of Indian cities
  const cities = [
    [19.0760, 72.8777], // Mumbai
    [28.7041, 77.1025], // Delhi
    [12.9716, 77.5946], // Bangalore
    [13.0827, 80.2707], // Chennai
    [22.5726, 88.3639], // Kolkata
    [17.3850, 78.4867], // Hyderabad
  ]

  // Convert lat/lng to 3D point on sphere (radius 2)
  const latLngToVector3 = (lat: number, lng: number) => {
    const phi = (90 - lat) * (Math.PI / 180)
    const theta = (lng + 180) * (Math.PI / 180)
    const r = 2.05
    return new THREE.Vector3(
      -(r * Math.sin(phi) * Math.cos(theta)),
      r * Math.cos(phi),
      r * Math.sin(phi) * Math.sin(theta)
    )
  }

  const points = cities.map(c => latLngToVector3(c[0], c[1]))

  // Connect them with arcs
  const arcs = []
  for (let i = 0; i < points.length; i++) {
    for (let j = i + 1; j < points.length; j++) {
      const p1 = points[i]
      const p2 = points[j]
      const distance = p1.distanceTo(p2)
      if (distance < 2.5) { // Only connect relatively close points
        const mid = p1.clone().add(p2).multiplyScalar(0.5).normalize().multiplyScalar(2 + distance * 0.2)
        const curve = new THREE.QuadraticBezierCurve3(p1, mid, p2)
        arcs.push(curve.getPoints(20))
      }
    }
  }

  return (
    <group ref={groupRef}>
      <Sphere args={[2, 64, 64]}>
        <meshBasicMaterial color="#0D1424" transparent opacity={0.9} />
      </Sphere>
      {/* Wireframe over the sphere */}
      <Sphere args={[2.01, 32, 32]}>
         <meshBasicMaterial color="#1F2937" wireframe transparent opacity={0.2} />
      </Sphere>
      
      {/* Hub markers */}
      {points.map((p, i) => (
        <mesh key={i} position={p}>
          <sphereGeometry args={[0.03, 16, 16]} />
          <meshBasicMaterial color="#2DD4BF" />
        </mesh>
      ))}

      {/* Connection arcs */}
      {arcs.map((points, i) => (
        <Line key={i} points={points} color="#FFB020" lineWidth={1} transparent opacity={0.6} />
      ))}
    </group>
  )
}

export function Globe() {
  return (
    <div className="w-full h-full absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_center,_#111827_0%,_#0B1020_100%)]">
      <Canvas camera={{ position: [0, 0, 5], fov: 45 }}>
        <ambientLight intensity={0.5} />
        <pointLight position={[10, 10, 10]} intensity={1} />
        <GlobeLines />
      </Canvas>
    </div>
  )
}
