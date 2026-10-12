import { Footer, Navbar } from "@/components/Brand";
import { PricingCards } from "@/components/Pricing";

export const metadata = { title: "Pricing" };

export default function PricingPage() {
  return (
    <>
      <Navbar />
      <main className="container-page py-16">
        <div className="mx-auto max-w-2xl text-center">
          <h1 className="text-4xl font-extrabold tracking-tight">Plans for every family</h1>
          <p className="mt-4 text-slate-600">SOS alerts are free on every plan. Always. Yearly plans get 2 months free.</p>
        </div>
        <div className="mt-12"><PricingCards /></div>
      </main>
      <Footer />
    </>
  );
}
