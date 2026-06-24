import styles from "../styles/Features.module.css";
import Image from "next/image";

interface ImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
}

function Features() {
  return (
    <div className={styles.featureGrid}>
      <div className={[styles.card, styles.dark].join(" ")}>
        <h1>Real-Time Tracking</h1>
        <p>Works in background / lockscreen</p>
        <Image alt="" src="/Cards/real-time.png" width={400} height={369} />
      </div>

      <div className={[styles.card, styles.green].join(" ")}>
        <Image alt="" src="/Cards/weekly-demo.png" width={400} height={488} />
        <h1 style={{ marginTop: "0.3em" }}>Monitor Posture Streaks</h1>
      </div>

      {/* <div className={[styles.card, styles.twitterBlue].join(' ')}>
                <Image alt='' src='/Cards/Twitter.png' width={400} height={319} />
                <h1 style={{marginTop: '0.5em'}}>Links from people you follow on Twitter, sorted by number of shares</h1>
            </div> */}

      <div className={[styles.card, styles.dark].join(" ")}>
        <h1>Auto-Activity Switching</h1>
        <p>
          Run or ride—your bear avatar instantly mirrors what you're doing in
          the real world
        </p>
        <Image alt="" src="/Cards/bear-running2.gif" width={400} height={469} />
      </div>

      <div
        className={[styles.card, styles.dark, styles.blueGradient].join(" ")}
      >
        <h1>Powered by  Core AI</h1>
      </div>
      <div className={[styles.card, styles.dark].join(" ")}>
        <Image alt="" src="/Cards/bear.png" width={400} height={388} />
        <h1 style={{ marginTop: "0.3em" }}>
          Smart Stretching with 3D Spatial Intelligence
        </h1>
      </div>

      <div className={[styles.card, styles.purple].join(" ")}>
        <Image alt="" src="/Cards/sit.png" width={400} height={227} />
        <h1 style={{ marginTop: "0.3em" }}>Live Activity Syncing</h1>
        <p>Check Live Activity from Mac/iPhone</p>
      </div>
    </div>
  );
}

export default Features;
