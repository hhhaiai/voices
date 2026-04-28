import Navbar from '@/components/Navbar'
import Hero from '@/components/sections/Hero'
import Features from '@/components/sections/Features'
import VideoSection from '@/components/sections/VideoSection'
import Benefits from '@/components/sections/Benefits'
import AdvancedFeatures from '@/components/sections/AdvancedFeatures'
import NativeMac from '@/components/sections/NativeMac'
import RealTime from '@/components/sections/RealTime'
import Languages from '@/components/sections/Languages'
import OpenSource from '@/components/sections/OpenSource'
import GetStarted from '@/components/sections/GetStarted'
import Pricing from '@/components/sections/Pricing'
import FAQ from '@/components/sections/FAQ'
import FinalCTA from '@/components/sections/FinalCTA'
import Footer from '@/components/sections/Footer'

export default function Home() {
  return (
    <div className="min-h-screen bg-black text-foreground">
      {/* Main bordered container */}
      <div className="main-container">
        <Navbar />
        <main>
          <Hero />
          <Features />
          <VideoSection />
          <Benefits />
          <AdvancedFeatures />
          <NativeMac />
          <RealTime />
          <Languages />
          <OpenSource />
          <GetStarted />
          <Pricing />
          <FAQ />
          <FinalCTA />
        </main>
        <Footer />
      </div>
    </div>
  )
}
