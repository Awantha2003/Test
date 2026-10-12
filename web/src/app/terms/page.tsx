import { Footer, Navbar } from "@/components/Brand";

export const metadata = { title: "Terms of service" };

export default function Terms() {
  return (
    <>
      <Navbar />
      <main className="container-page max-w-3xl py-16">
        <article className="space-y-5 text-slate-700 [&_h2]:mt-8 [&_h2]:text-xl [&_h2]:font-bold [&_h2]:text-slate-900">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900">Terms of service</h1>
          <p className="text-sm text-slate-500">Template: have it reviewed by a Sri Lankan lawyer before launch.</p>
          <h2>Who can use Rakawala</h2>
          <p>Guardian accounts are for adults (18+) who are the parent or legal guardian of the children they add. You may only install the child app on a device you are responsible for, with the child&apos;s knowledge.</p>
          <h2>Not an emergency service</h2>
          <p>
            Rakawala relies on mobile networks, GPS and phone settings that we don&apos;t control. Locations can be delayed or inaccurate and alerts can fail.
            <b> In an emergency always call 119 (Police) or 1929 (Child helpline).</b>
          </p>
          <h2>Subscriptions</h2>
          <p>Paid plans renew automatically through PayHere until cancelled. If you cancel, you keep access until the end of the paid period. Prices are in LKR and include applicable taxes.</p>
          <h2>Acceptable use</h2>
          <p>You must not use Rakawala to track anyone without their knowledge, including partners or other adults. We will suspend accounts that misuse the service.</p>
          <h2>Liability</h2>
          <p>To the extent permitted by law, Rakawala is not liable for losses caused by service interruptions, inaccurate locations or missed alerts.</p>
        </article>
      </main>
      <Footer />
    </>
  );
}
