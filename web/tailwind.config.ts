import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { 50: "#EFF4FF", 100: "#DBE6FE", 500: "#2563EB", 600: "#1D4ED8", 700: "#1E40AF", 900: "#1E3A8A" },
        sos: "#DC2626",
        safe: "#059669",
        warn: "#D97706",
      },
      fontFamily: { sans: ["Inter", "Noto Sans Sinhala", "system-ui", "sans-serif"] },
      boxShadow: { card: "0 1px 2px rgba(15,23,42,.04), 0 4px 16px rgba(15,23,42,.06)" },
    },
  },
  plugins: [],
} satisfies Config;
