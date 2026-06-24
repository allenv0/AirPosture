import fs from 'fs'
import path from 'path'
import matter from 'gray-matter'
import { MDXRemote, MDXRemoteProps } from 'next-mdx-remote'
import Link from 'next/link'
import Head from 'next/head'
import { serialize } from 'next-mdx-remote/serialize'

interface BlogPostProps {
  frontMatter: {
    title: string
    date: string
    excerpt?: string
    ogImage?: string
  }
  slug: string
  mdxSource: MDXRemoteProps
}

const mdxComponents = {
  h1: (props: any) => (
    <h1
      style={{
        fontSize: '2em',
        fontWeight: 600,
        letterSpacing: '-0.02em',
        color: '#FFFFFF',
        lineHeight: '1.3',
        marginTop: '48px',
        marginBottom: '24px',
        textShadow: '0 2px 10px rgba(0, 0, 0, 0.3)',
      }}
      {...props}
    />
  ),
  h2: (props: any) => (
    <h2
      style={{
        fontSize: '1.5em',
        fontWeight: 600,
        letterSpacing: '-0.02em',
        color: '#FFFFFF',
        lineHeight: '1.4',
        marginTop: '40px',
        marginBottom: '20px',
        textShadow: '0 2px 10px rgba(0, 0, 0, 0.3)',
      }}
      {...props}
    />
  ),
  h3: (props: any) => (
    <h3
      style={{
        fontSize: '1.25em',
        fontWeight: 600,
        letterSpacing: '-0.02em',
        color: '#FFFFFF',
        lineHeight: '1.4',
        marginTop: '32px',
        marginBottom: '16px',
        textShadow: '0 2px 10px rgba(0, 0, 0, 0.3)',
      }}
      {...props}
    />
  ),
  p: (props: any) => (
    <p
      style={{
        fontSize: '1.0625em',
        color: 'rgba(255, 255, 255, 0.9)',
        lineHeight: '1.75',
        marginTop: '0',
        marginBottom: '24px',
        fontWeight: 400,
      }}
      {...props}
    />
  ),
  ul: (props: any) => (
    <ul
      style={{
        paddingLeft: '24px',
        marginBottom: '24px',
      }}
      {...props}
    />
  ),
  ol: (props: any) => (
    <ol
      style={{
        paddingLeft: '24px',
        marginBottom: '24px',
      }}
      {...props}
    />
  ),
  li: (props: any) => (
    <li
      style={{
        fontSize: '1.0625em',
        color: 'rgba(255, 255, 255, 0.9)',
        lineHeight: '1.75',
        marginBottom: '8px',
        fontWeight: 400,
      }}
      {...props}
    />
  ),
  a: (props: any) => (
    <a
      style={{
        color: '#3D8BFF',
        textDecoration: 'none',
        transition: 'color 0.15s ease',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.color = '#66a3ff'
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.color = '#3D8BFF'
      }}
      {...props}
    />
  ),
  blockquote: (props: any) => (
    <blockquote
      style={{
        borderLeft: '3px solid rgba(255, 255, 255, 0.2)',
        paddingLeft: '20px',
        margin: '32px 0',
        fontStyle: 'italic',
        color: 'rgba(255, 255, 255, 0.85)',
      }}
      {...props}
    />
  ),
  code: (props: any) => (
    <code
      style={{
        backgroundColor: 'rgba(255, 255, 255, 0.1)',
        padding: '3px 6px',
        borderRadius: '4px',
        fontSize: '0.9375em',
        color: '#FFFFFF',
        fontFamily: '"SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace',
        border: '1px solid rgba(255, 255, 255, 0.1)',
      }}
      {...props}
    />
  ),
  pre: (props: any) => (
    <pre
      style={{
        backgroundColor: 'rgba(0, 0, 0, 0.4)',
        color: '#fafafa',
        padding: '20px',
        borderRadius: '12px',
        overflow: 'auto',
        marginBottom: '24px',
        fontSize: '0.875em',
        lineHeight: '1.6',
        border: '1px solid rgba(255, 255, 255, 0.1)',
        backdropFilter: 'blur(10px)',
        WebkitBackdropFilter: 'blur(10px)',
      }}
      {...props}
    />
  ),
  table: (props: any) => (
    <div style={{ overflowX: 'auto', marginBottom: '24px' }}>
      <table
        style={{
          width: '100%',
          borderCollapse: 'collapse',
          fontSize: '1em',
        }}
        {...props}
      />
    </div>
  ),
  thead: (props: any) => (
    <thead
      style={{
        borderBottom: '2px solid rgba(255, 255, 255, 0.2)',
      }}
      {...props}
    />
  ),
  tbody: (props: any) => <tbody {...props} />,
  tr: (props: any) => (
    <tr
      style={{
        borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
      }}
      {...props}
    />
  ),
  th: (props: any) => (
    <th
      style={{
        textAlign: 'left',
        padding: '12px 16px',
        fontWeight: 600,
        color: '#FFFFFF',
        fontSize: '0.9375em',
      }}
      {...props}
    />
  ),
  td: (props: any) => (
    <td
      style={{
        padding: '12px 16px',
        color: 'rgba(255, 255, 255, 0.9)',
      }}
      {...props}
    />
  ),
  hr: (props: any) => (
    <hr
      style={{
        border: 'none',
        borderTop: '1px solid rgba(255, 255, 255, 0.1)',
        margin: '48px 0',
      }}
      {...props}
    />
  ),
  img: (props: any) => (
    <img
      style={{
        maxWidth: '100%',
        height: 'auto',
        borderRadius: '12px',
        margin: '32px 0',
        border: '1px solid rgba(255, 255, 255, 0.1)',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.3)',
      }}
      {...props}
      alt={props.alt || ''}
    />
  ),
}

export default function BlogPost({ frontMatter, slug, mdxSource }: BlogPostProps) {
  const ogImage = frontMatter.ogImage || '/og/default.png'
  const description = frontMatter.excerpt || 'AirPosture Blog - Thoughts, updates, and insights from the team'
  const url = `https://airposture.pro/blog/${slug}`

  return (
    <>
      <Head>
        {/* Primary Open Graph tags */}
        <meta property="og:title" content={frontMatter.title} />
        <meta property="og:description" content={description} />
        <meta property="og:image" content={ogImage} />
        <meta property="og:url" content={url} />
        <meta property="og:type" content="article" />
        <meta property="og:site_name" content="AirPosture" />

        {/* Twitter Card tags */}
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={frontMatter.title} />
        <meta name="twitter:description" content={description} />
        <meta name="twitter:image" content={ogImage} />

        {/* Additional meta */}
        <meta name="description" content={description} />
      </Head>

      <style jsx global>{`
        body {
          background: #000000;
        }
      `}</style>

      <div style={{
        maxWidth: '720px',
        margin: '0 auto',
        padding: '80px 24px 100px',
        fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
        position: 'relative',
      }}>
        {/* Background gradient mesh */}
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'radial-gradient(at 47% 33%, hsl(220, 70%, 30%) 0, transparent 59%), radial-gradient(at 82% 65%, hsl(210, 65%, 25%) 0, transparent 55%)',
          opacity: 0.2,
          zIndex: -1,
          pointerEvents: 'none',
        }} />

        {/* Back Button */}
        <Link
          href="/blog"
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            fontSize: '0.9375em',
            fontWeight: 600,
            color: 'rgba(255, 255, 255, 0.7)',
            textDecoration: 'none',
            marginBottom: '40px',
            transition: 'color 0.15s ease',
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.color = '#FFFFFF'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.color = 'rgba(255, 255, 255, 0.7)'
          }}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            style={{ marginRight: '8px' }}
          >
            <path
              d="M10 3L5 8L10 13"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          Back to blog
        </Link>

        {/* Article */}
        <article style={{
          padding: '48px',
          borderRadius: '30px',
          background: 'rgba(0, 0, 0, 0.2)',
          backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          boxShadow: '0 8px 32px rgba(31, 38, 135, 0.15)',
          position: 'relative',
          overflow: 'hidden',
        }}>
          {/* Gradient overlay */}
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'radial-gradient(circle at 30% 70%, rgba(15, 29, 59, 0.18) 0%, transparent 50%)',
            pointerEvents: 'none',
            zIndex: 0,
          }} />

          <div style={{ position: 'relative', zIndex: 1 }}>
            {/* Header */}
            <header style={{ marginBottom: '48px' }}>
              <h1 style={{
                fontSize: '2.75em',
                fontWeight: 700,
                letterSpacing: '-0.02em',
                background: 'linear-gradient(135deg, #FFFFFF 0%, #F5F5F5 25%, #E8E8E8 50%, #F5F5F5 75%, #FFFFFF 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
                color: 'transparent',
                textShadow: '0 2px 10px rgba(0, 0, 0, 0.3)',
                lineHeight: '1.2',
                marginBottom: '20px',
              }}>
                {frontMatter.title}
              </h1>
              <time style={{
                fontSize: '1em',
                color: 'rgba(255, 255, 255, 0.6)',
                fontWeight: 500,
                letterSpacing: '0.01em',
              }}>
                {frontMatter.date}
              </time>
            </header>

            {/* Content */}
            <div style={{ fontSize: '1.0625em' }}>
              <MDXRemote {...mdxSource} components={mdxComponents} />
            </div>
          </div>
        </article>
      </div>
    </>
  )
}

export async function getStaticPaths() {
  const files = fs.readdirSync(path.join('content/blog'))

  const paths = files
    .filter((filename) => filename.endsWith('.mdx'))
    .map((filename) => ({
      params: {
        slug: filename.replace('.mdx', ''),
      },
    }))

  return {
    paths,
    fallback: false,
  }
}

export async function getStaticProps({ params }: { params: { slug: string } }) {
  const filePath = path.join('content/blog', `${params.slug}.mdx`)
  const fileContent = fs.readFileSync(filePath, 'utf-8')
  const { data: frontMatter, content } = matter(fileContent)

  const mdxSource = await serialize(content)

  return {
    props: {
      frontMatter,
      slug: params.slug,
      mdxSource,
    },
  }
}
