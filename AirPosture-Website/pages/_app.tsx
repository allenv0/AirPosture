import '../styles/globals.css'
import type { AppProps } from 'next/app'
import Head from 'next/head'
import { MDXProvider } from '@mdx-js/react'

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <MDXProvider>
      <>
        <Head>
          <link rel="icon" type="image/png" sizes="32x32" href="/Icon.png" />
          <link rel="icon" type="image/png" sizes="16x16" href="/Icon.png" />
          <link rel="apple-touch-icon" sizes="180x180" href="/Icon.png" />
        </Head>
        <Component {...pageProps} />
      </>
    </MDXProvider>
  )
}

export default MyApp
