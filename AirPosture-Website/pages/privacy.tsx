import type { NextPage } from "next";
import Head from "next/head";
import Base from "../components/base";
import Header from "../components/header";

function Privacy() {
  return (
    <div>
      <Head>
        <title>Privacy Policy | AirPosture app</title>
        <link rel="icon" href="/Icon.png" />
      </Head>

      <Base>
        <Header />
        <h1>Privacy Policy</h1>
        <p>Last Updated: Mar 12, 2026</p>

        <p>
          At AirPosture, your privacy is our top priority. This Privacy Policy
          explains our commitment to protecting your personal information and
          data.
        </p>

        <h2>No Data Collection</h2>
        <p>
          We do not collect, store, or process any personal information or user
          data. When you use AirPosture, all data remains on your device and is
          never transmitted to our servers or any third parties.
        </p>

        <h2>Local Data Processing</h2>
        <p>
          All posture data is processed locally on your device. This includes:
        </p>
        <ul>
          <li>Sensor data from your AirPods</li>
          <li>Posture detection and analysis</li>
          <li>Performance metrics and statistics</li>
          <li>Usage patterns and preferences</li>
        </ul>
        <p>
          This data is used solely to provide the core functionality of the app
          and is never shared with us or anyone else.
        </p>

        <h2>Analytics</h2>
        <p>
          We've integrated Firebase analytics to better understand active usage and
          retention so we can improve future updates. No personal content is collected.
        </p>

        <h2>Third-Party Services</h2>
        <p>
          AirPosture uses Firebase analytics to understand app usage and improve the
          user experience. No personal content is collected. The app does not integrate
          with or rely on any other third-party services that would collect your data.
        </p>

        <h2>Data Security</h2>
        <p>
          Since we do not collect or store any of your data, there is no risk of
          your information being compromised through our services. Your data
          never leaves your device, ensuring maximum security and privacy.
        </p>

        <h2>Children's Privacy</h2>
        <p>
          AirPosture does not collect personal information from anyone,
          including children under the age of 13. No data is stored or
          transmitted, making our service safe for users of all ages.
        </p>

        <h2>Changes to This Privacy Policy</h2>
        <p>
          We may update our Privacy Policy from time to time. Any changes will
          be posted on this page with an updated "Last Updated" date. We
          encourage you to review this Privacy Policy periodically for any
          changes.
        </p>

        <h2>Contact Us</h2>
        <p>
          If you have any questions about this Privacy Policy, please{" "}
          <a href="/support">visit our Support page</a> or contact us at:{" "}
          <a href="mailto:allenleexyz@gmail.com">allenleexyz@gmail.com</a>
        </p>
      </Base>
    </div>
  );
}

export default Privacy;
