import type { NextPage } from "next";
import Head from "next/head";
import Base from "../components/base";
import Header from "../components/header";

function Terms() {
  return (
    <div>
      <Head>
        <title>Terms of Use | AirPosture app</title>
        <link rel="icon" href="/Icon.png" />
      </Head>
      <Base>
        <Header />
        <h1>Terms of Use</h1>
        <p>Last updated: Mar 12, 2026</p>
        <p>
          Welcome to AirPosture! By using our app, you agree to these terms.
          Please read them carefully.
        </p>
        <h2>Our Commitment to Your Privacy</h2>
        <p>
          Your privacy is at the core of everything we do. As our{" "}
          <a href="/privacy">Privacy Policy</a> explains, we use Firebase analytics
          to understand app usage and improve the user experience, but no personal
          content is collected. All data processing happens on your device, and
          nothing is ever sent to us or any third parties.
        </p>
        <h2>Using Our App</h2>
        <p>
          AirPosture is designed to help you improve your posture. You can use
          our app for personal, non-commercial purposes. You must be at least 13
          years old to use our app.
        </p>
        <h2>Disclaimer of Warranties</h2>
        <p>
          We do our best to provide a great experience, but our app is provided
          "as is" without any warranties. We don't guarantee that the app will
          always be perfect, but we're always working to improve it.
        </p>
        <h2>Limitation of Liability</h2>
        <p>
          We are not liable for any damages or losses that may result from your
          use of the app. Please use it responsibly.
        </p>
        <h2>Changes to These Terms</h2>
        <p>
          We may update these terms from time to time. If we make significant
          changes, we will do our best to let you know. By continuing to use the
          app after the changes, you agree to the new terms.
        </p>
        <h2>Contact Us</h2>
        <p>
          If you have any questions about these terms, please contact us at:{" "}
          <a href="mailto:allenleexyz@gmail.com">allenleexyz@gmail.com</a>
        </p>
      </Base>
    </div>
  );
}
export default Terms;
