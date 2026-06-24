import Head from "next/head";
import Link from "next/link";
import Base from "../components/base";
import Header from "../components/header";
import styles from "../styles/Base.module.css";

function Support() {
  return (
    <div>
      <Head>
        <title>Support | AirPosture</title>
        <link rel="icon" href="/Icon.png" />
      </Head>

      <Base>
        <Header />
        <div className={styles.page}>
          <h1>Support</h1>
          <p>We're here to help you get the most out of AirPosture.</p>

          <div className={styles.callout}>
            <strong>Quick help:</strong> Email us at{" "}
            <a href="mailto:allenleexyz@gmail.com">allenleexyz@gmail.com</a>{" "}
            and we&apos;ll get back to you as soon as possible.
          </div>

          <h2>Getting Started</h2>
          <h3>How do I use AirPosture?</h3>
          <p>
            Simply download the app from the App Store, put in your AirPods, and
            open AirPosture then click start. The app will automatically begin
            detecting your head position using the motion sensors in your
            AirPods. When you slouch, you&apos;ll receive a gentle notification
            to correct your posture.
          </p>

          <h3>Which AirPods are supported?</h3>
          <p>
            AirPosture works with AirPods Pro (1st and 2nd generation), AirPods
            (3rd generation), and AirPods Max. These models contain the motion
            sensors needed for posture detection.
          </p>

          <h2>Troubleshooting</h2>
          <h3>AirPosture isn&apos;t detecting my head movements</h3>
          <p>
            Make sure your AirPods are connected to your iPhone via Bluetooth
            and that they are properly seated in your ears. If the issue
            persists, try disconnecting and reconnecting your AirPods in the
            Bluetooth settings.
          </p>

          <h3>I&apos;m not receiving posture alerts</h3>
          <p>
            Check that notifications are enabled for AirPosture in your
            iPhone&apos;s Settings app. Go to{" "}
            <strong>Settings &gt; Notifications &gt; AirPosture</strong> and
            make sure &quot;Allow Notifications&quot; is turned on.
          </p>

          <h3>The app isn&apos;t working as expected</h3>
          <p>
            Try force-quitting the app and reopening it. If the problem
            continues, restart your iPhone. Most issues can be resolved with a
            simple restart.
          </p>

          <h2>Battery &amp; Performance</h2>
          <h3>Does AirPosture drain my AirPods battery?</h3>
          <p>
            AirPosture is designed to be energy-efficient. It uses the existing
            motion sensors in your AirPods, which consume minimal power. You
            should not notice a significant difference in battery life during
            normal use.
          </p>

          <h3>Does it affect iPhone battery life?</h3>
          <p>
            AirPosture runs efficiently in the background. Battery impact is
            minimal and comparable to other health and fitness apps.
          </p>

          <h2>Privacy &amp; Data</h2>
          <p>
            Your privacy is our top priority. All posture data is processed
            locally on your device and is never transmitted to our servers. For
            full details, please read our{" "}
            <Link href="/privacy">Privacy Policy</Link>.
          </p>

          <h2>Still Need Help?</h2>
          <p>
            If you didn&apos;t find what you were looking for, please reach out
            to us directly:
          </p>
          <ul>
            <li>
              <strong>Email:</strong>{" "}
              <a href="mailto:allenleexyz@gmail.com">allenleexyz@gmail.com</a>
            </li>
            <li>
              <strong>X (Twitter):</strong>{" "}
              <a href="https://x.com/allenleexyz" target="_blank" rel="noopener noreferrer">
                @allenleexyz
              </a>
            </li>
          </ul>
          <p>
            We strive to respond to all inquiries within 24&ndash;48 hours.
          </p>
        </div>
      </Base>
    </div>
  );
}

export default Support;
