import { Footer, Navbar } from "@/components/Brand";

export const metadata = { title: "Privacy policy" };

export default function Privacy() {
  return (
    <>
      <Navbar />
      <main className="container-page max-w-3xl py-16">
        <article className="space-y-5 text-slate-700 [&_h2]:mt-8 [&_h2]:text-xl [&_h2]:font-bold [&_h2]:text-slate-900">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900">Privacy policy</h1>
          <p className="text-sm text-slate-500">Template: have it reviewed by a Sri Lankan lawyer before launch.</p>
          <p>Rakawala helps parents and guardians keep their children safe. This policy explains what we collect, why, and your rights under the Personal Data Protection Act No. 9 of 2022.</p>
          <h2>What we collect</h2>
          <ul className="list-disc space-y-1 pl-6">
            <li><b>Guardian account:</b> name, email, optional mobile number (for SOS SMS).</li>
            <li><b>Child device:</b> location, speed, battery level and device name, collected <b>only with the guardian&apos;s consent</b> and visible to the child.</li>
            <li><b>Alerts</b> you receive (arrivals, SOS, etc.) and the places and schedules you create.</li>
            <li><b>Payments</b> are handled by PayHere. We never see or store card numbers.</li>
          </ul>
          <h2>What we don&apos;t do</h2>
          <ul className="list-disc space-y-1 pl-6">
            <li>We never sell data or use it for advertising.</li>
            <li>We don&apos;t record audio. Voice SOS is recognised on the device.</li>
            <li>Our staff cannot view children&apos;s live location or history.</li>
          </ul>
          <h2>Retention</h2>
          <p>Location history is deleted automatically after 1–90 days depending on your plan. Deleting your account deletes your family&apos;s data within 30 days (backups included).</p>
          <h2>Your rights</h2>
          <p>You can access, correct, export or delete your data at any time from the app (Settings → Delete account) or by contacting privacy@rakawala.lk.</p>
          <h2>Security</h2>
          <p>Data is encrypted in transit (TLS) and at rest, access is restricted per family, and app-integrity checks block modified apps. See our security overview for details.</p>
          <h2>Children</h2>
          <p>Child accounts are created only by a parent or legal guardian, who consents on the child&apos;s behalf. Children always see when location sharing is active.</p>
        </article>
      </main>
      <Footer />
    </>
  );
}
