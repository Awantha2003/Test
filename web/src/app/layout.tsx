import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Providers } from "@/components/Providers";

export const metadata: Metadata = {
  title: { default: "Rakawala: Child Safety for Sri Lankan Families", template: "%s · Rakawala" },
  description: "Live location, tuition-class arrival alerts and one-tap SOS for your children. Built in Sri Lanka, priced in LKR.",
  applicationName: "Rakawala",
  openGraph: {
    title: "Rakawala: Know they're safe",
    description: "Live location, class-arrival alerts and SOS for your children.",
    type: "website",
    locale: "en_LK",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = { themeColor: "#1D4ED8", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
