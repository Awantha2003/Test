/**
 * Static export: the site is served from Firebase Hosting / any CDN.
 * All private data is fetched client-side through the Firebase SDK and protected by
 * Firestore rules + App Check. Security headers are set in firebase/firebase.json (hosting).
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: "export",
  trailingSlash: true,
  reactStrictMode: true,
  poweredByHeader: false,
  images: { unoptimized: true },
};
export default nextConfig;
