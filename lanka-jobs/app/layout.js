import './globals.css';
import Link from 'next/link';

export const metadata = {
  title: 'Lanka Jobs — SE, IT & Internships in Sri Lanka',
  description: 'All Sri Lankan software engineering, IT and internship jobs in one place, checked every 5 minutes.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <header className="top">
          <div className="wrap nav">
            <Link href="/" className="brand">
              🇱🇰 Lanka<span>Jobs</span>
            </Link>
            <nav>
              <Link href="/">Jobs</Link>
              <Link href="/applications">My applications</Link>
              <Link href="/sources">Sources</Link>
              <Link href="/settings">Settings</Link>
            </nav>
          </div>
        </header>
        <main className="wrap">{children}</main>
      </body>
    </html>
  );
}
