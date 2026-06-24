import type { NextPage } from 'next'
import Head from 'next/head'
import Base from '../components/base'
import Header from '../components/header'
import styles from '../styles/Base.module.css'

function Test() {
    return (
      <div>
        <Head>
          <title>Paradoxically, Parakeets Prefer Parkour</title>
          <link rel="icon" href="/Icon.png" />
        </Head>

        <Base>
            <article>
                {/* <img style={{width: '100%'}} src="/bird.jpg" alt="Parakeet" /> */}
            <h1>Paradoxically, Parakeets Prefer Parkour</h1>
        <p>In a surprising turn of events, our local parakeets have been spotted embracing their inner daredevils and taking up an unexpected hobby – parkour!</p>

        <p>For years, these colorful and chirpy birds have been known for their love of perching on trees and feeding on seeds in the neighborhood park. However, recent sightings have shown a remarkable shift in their behavior.</p>

        <p>Local birdwatchers and nature enthusiasts have been witnessing parakeets engaging in what can only be described as avian parkour, defying gravity with their agile moves. These feathered acrobats have been observed gracefully leaping from branch to branch, performing mid-air flips, and even swinging from tree vines like tiny Tarzans.</p>

        <p>Emily Thompson, a resident who frequents the park, shared her excitement, saying, "I couldn't believe my eyes when I saw those parakeets flipping through the air. It's like they've become little daredevils overnight!"</p>

        <p>Biologists and ornithologists are equally fascinated by this phenomenon. Dr. Sarah Roberts, an avian expert, suggests that this newfound fascination with parkour might be a result of the parakeets' natural curiosity and adaptability.</p>

        <p>"Parakeets are incredibly intelligent birds. They are always looking for ways to stay mentally and physically active. Parkour seems to be an excellent outlet for their energy," Dr. Roberts explained.</p>

            </article>
        </Base>
    </div>
    )
}

export default Test;
