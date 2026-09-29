import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { ThemeProvider } from "next-themes";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthCallbackHandler } from "@/components/auth-callback-handler";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://trinexbusinesspay.netlify.app"),
  title: "TRINEX BusinessPay — Finance Dashboard",
  description: "TRINEX BusinessPay is a modern finance dashboard built with Next.js, shadcn/ui, and Tailwind CSS.",
  openGraph: {
    title: "TRINEX BusinessPay — Finance Dashboard",
    description: "A modern finance dashboard built with Next.js, shadcn/ui, and Tailwind CSS.",
    type: "website",
    url: "https://trinexbusinesspay.netlify.app",
    images: [{ url: "/screenshots/trinex-businesspay.png", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TRINEX BusinessPay — Finance Dashboard",
    description: "A modern finance dashboard built with Next.js, shadcn/ui, and Tailwind CSS.",
    images: ["/screenshots/trinex-businesspay.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased font-sans`}
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col">
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
          <TooltipProvider><AuthCallbackHandler>{children}</AuthCallbackHandler></TooltipProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
