import fs from "fs";
import path from "path";
import matter from "gray-matter";
import Link from "next/link";
import Head from "next/head";

interface BlogPost {
  slug: string;
  title: string;
  date: string;
  excerpt: string;
}

interface BlogIndexProps {
  posts: BlogPost[];
}

export default function BlogIndex({ posts }: BlogIndexProps) {
  return (
    <>
      <Head>
        {/* Primary Open Graph tags */}
        <meta property="og:title" content="AirPosture Blog" />
        <meta
          property="og:description"
          content="Thoughts, updates, and insights from the team"
        />
        <meta property="og:image" content="/og/default.png" />
        <meta property="og:url" content="https://airposture.pro/blog" />
        <meta property="og:type" content="website" />
        <meta property="og:site_name" content="AirPosture" />

        {/* Twitter Card tags */}
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="AirPosture Blog" />
        <meta
          name="twitter:description"
          content="Thoughts, updates, and insights from the team"
        />
        <meta name="twitter:image" content="/og/default.png" />

        {/* Additional meta */}
        <meta
          name="description"
          content="Thoughts, updates, and insights from the team"
        />
      </Head>

      <style jsx global>{`
        body {
          background: #000000;
        }
      `}</style>

      <div
        style={{
          maxWidth: "900px",
          margin: "0 auto",
          padding: "80px 24px 60px",
          fontFamily:
            "'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
          position: "relative",
        }}
      >
        {/* Background gradient mesh */}
        <div
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background:
              "radial-gradient(at 47% 33%, hsl(220, 70%, 30%) 0, transparent 59%), radial-gradient(at 82% 65%, hsl(210, 65%, 25%) 0, transparent 55%)",
            opacity: 0.2,
            zIndex: -1,
            pointerEvents: "none",
          }}
        />

        {/* Header */}
        <div style={{ marginBottom: "60px", textAlign: "center" }}>
          <h1
            style={{
              fontSize: "3.5em",
              fontWeight: 700,
              letterSpacing: "-0.02em",
              marginBottom: "16px",
              background:
                "linear-gradient(135deg, #FFFFFF 0%, #F5F5F5 25%, #E8E8E8 50%, #F5F5F5 75%, #FFFFFF 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              backgroundClip: "text",
              color: "transparent",
              textShadow: "0 2px 10px rgba(0, 0, 0, 0.3)",
              lineHeight: "1.1",
            }}
          >
            AirPosture Blog
          </h1>
          <p
            style={{
              fontSize: "1.1em",
              color: "rgba(255, 255, 255, 0.75)",
              lineHeight: "1.6",
              fontWeight: 500,
              letterSpacing: "0.01em",
            }}
          >
            Thoughts, updates, and insights from our team
          </p>
        </div>

        {/* Blog Posts */}
        <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
          {posts.map((post) => (
            <Link
              key={post.slug}
              href={`/blog/${post.slug}`}
              style={{ textDecoration: "none", color: "inherit" }}
            >
              <article
                style={{
                  padding: "32px",
                  borderRadius: "20px",
                  background: "rgba(0, 0, 0, 0.2)",
                  backdropFilter: "blur(20px)",
                  WebkitBackdropFilter: "blur(20px)",
                  border: "1px solid rgba(255, 255, 255, 0.1)",
                  boxShadow: "0 8px 32px rgba(31, 38, 135, 0.15)",
                  transition: "all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94)",
                  transform: "translateZ(0)",
                  position: "relative",
                  overflow: "hidden",
                  cursor: "pointer",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform =
                    "translateY(-4px) scale(1.03)";
                  e.currentTarget.style.boxShadow =
                    "0 20px 60px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.15)";
                  e.currentTarget.style.borderColor =
                    "rgba(255, 255, 255, 0.15)";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = "translateZ(0)";
                  e.currentTarget.style.boxShadow =
                    "0 8px 32px rgba(31, 38, 135, 0.15)";
                  e.currentTarget.style.borderColor =
                    "rgba(255, 255, 255, 0.1)";
                }}
              >
                {/* Gradient overlay on hover */}
                <div
                  style={{
                    position: "absolute",
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    background:
                      "linear-gradient(135deg, transparent 30%, rgba(255, 255, 255, 0.05) 100%)",
                    opacity: 0,
                    transition: "opacity 0.4s ease",
                    pointerEvents: "none",
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.opacity = "1";
                  }}
                />

                <div style={{ position: "relative", zIndex: 1 }}>
                  {/* Date */}
                  <time
                    style={{
                      fontSize: "0.875em",
                      color: "rgba(255, 255, 255, 0.6)",
                      fontWeight: 500,
                      letterSpacing: "0.01em",
                      marginBottom: "12px",
                      display: "block",
                    }}
                  >
                    {post.date}
                  </time>

                  {/* Title */}
                  <h2
                    style={{
                      fontSize: "1.75em",
                      fontWeight: 600,
                      letterSpacing: "-0.02em",
                      color: "#FFFFFF",
                      lineHeight: "1.3",
                      margin: "0 0 16px 0",
                      textShadow: "0 2px 10px rgba(0, 0, 0, 0.3)",
                    }}
                  >
                    {post.title}
                  </h2>

                  {/* Excerpt */}
                  <p
                    style={{
                      fontSize: "1em",
                      color: "rgba(255, 255, 255, 0.9)",
                      lineHeight: "1.6",
                      margin: "0 0 16px 0",
                      fontWeight: 400,
                    }}
                  >
                    {post.excerpt}
                  </p>

                  {/* Read More */}
                  <span
                    style={{
                      display: "inline-flex",
                      alignItems: "center",
                      fontSize: "0.9375em",
                      fontWeight: 600,
                      color: "#3D8BFF",
                      letterSpacing: "0.01em",
                      transition: "color 0.15s ease",
                    }}
                  >
                    Read article
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 16 16"
                      fill="none"
                      style={{
                        marginLeft: "8px",
                        transition: "transform 0.15s ease",
                      }}
                    >
                      <path
                        d="M3 8H13M13 8L9 4M13 8L9 12"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </span>
                </div>
              </article>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}

export async function getStaticProps() {
  const files = fs.readdirSync(path.join("content/blog"));

  const posts = files
    .filter((filename) => filename.endsWith(".mdx"))
    .map((filename) => {
      const filePath = path.join("content/blog", filename);
      const fileContent = fs.readFileSync(filePath, "utf-8");
      const { data } = matter(fileContent);

      return {
        slug: filename.replace(".mdx", ""),
        title: data.title || "",
        date: data.date || "",
        excerpt: data.excerpt || "",
      };
    })
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  return {
    props: {
      posts,
    },
  };
}
