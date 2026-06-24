import Head from "next/head";
import MemoDeck from "../components/MemoDeck";

export default function DeckPage() {
  return (
    <>
      <Head>
        <title>AirPosture Deck</title>
        <meta name="description" content="AirPosture - AI Posture Assistant Pitch Deck" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </Head>
      <MemoDeck />
    </>
  );
}
