import type { NextPage } from "next";
import Head from "next/head";
import Link from "next/link";
import Image from "next/image";
import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import Features from "../components/features";
import LoveCards from "../components/LoveCards";
import EmailInputPopup from "../components/EmailInputPopup";
import styles from "../styles/Home.module.css";
import { APP_STORE_LINK } from "../utils/links";
import DownloadButton from "../components/DownloadButton";

const Analytics = dynamic<any>(
  () => import("@vercel/analytics/react").then((mod) => mod.Analytics),
  { ssr: false },
);

function Home() {
  const [isPopupOpen, setIsPopupOpen] = useState(false);

  useEffect(() => {
    const el = document.querySelector("html");
    if (el) {
      el.style.backgroundColor = "#000000";
    }
  });

  const handleEmailSubmit = async (email: string) => {
    const response = await fetch("/api/waitlist", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ email }),
    });

    if (!response.ok) {
      throw new Error("Failed to submit email");
    }

    return response.json();
  };
  return (
    <div className={styles.container}>
      <Head>
        <title>AirPosture: AirPods as Posture Coach</title>
        <meta name="description" content="AirPods as Posture Coach" />
        <link rel="icon" href="/Icon.png" />
        <meta name="theme-color" content="#0A2A66" />
        <meta property="og:image" content="/og.png" />
        <meta
          property="og:title"
          content="AirPosture: AirPods as Posture Coach"
        />
        <meta
          property="og:description"
          content="Unlocks the hidden sensors in your AirPods, turning them into a real-time posture coach for work and workouts on iOS"
        />
        <meta property="og:url" content="https://airposture.pro" />
        <meta property="og:type" content="website" />
        <meta property="og:site_name" content="AirPosture" />
        <meta property="og:locale" content="en_US" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta
          name="twitter:title"
          content="AirPosture: AirPods as Posture Coach"
        />
        <meta
          name="twitter:description"
          content="Unlocks the hidden sensors in your AirPods, turning them into a real-time posture coach for work and workouts on iOS"
        />
        <meta name="twitter:image" content="/og.png" />
      </Head>
      <Analytics />

      <Splash />

      <div className={styles.whitePage}>
        <h1 className={`${styles.featuresLabel} silver-gradient-text`}>
          What's Special
        </h1>
        <Features />
      </div>

      <div className={styles.blackPage}>
        <LoveCards />
      </div>

      <footer className={styles.footer}>
        <Link href="/privacy">Privacy</Link>
        <Link href="/terms">Terms</Link>
        <Link href="/support">Support</Link>
        <Link
          href="https://x.com/allenleexyz"
          target="_blank"
          rel="noopener noreferrer"
        >
          Follow on X
        </Link>
      </footer>
    </div>
  );
}

interface SplashCTAProps {
  hidden?: boolean;
}

function Splash() {
  return (
    <div className={styles.splash}>
      <div className={styles.phonePic} />
      <SplashCTA />
    </div>
  );
}

function SplashCTA({ hidden }: SplashCTAProps) {
  return (
    <div
      className={styles.splashCTA}
      style={{ opacity: hidden ? 0 : 1 }}
      aria-hidden={hidden}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "12px", marginBottom: "8px" }}>
        <Image src="/air.png" alt="AirPosture" width={55} height={55} style={{ marginBottom: "8px" }} />
        <h1 className="silver-gradient-text" style={{ margin: 0 }}>AirPosture</h1>
      </div>
      <p>
        Unlocks the hidden sensors in your AirPods, turning them into a
        real-time posture coach for work and workouts on iOS
      </p>
      <DownloadButton showSubtitle={true} />
    </div>
  );
}

export default Home;
