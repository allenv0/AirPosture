import fs from "fs";
import path from "path";
import matter from "gray-matter";
import { MDXRemote, MDXRemoteProps } from "next-mdx-remote";
import Head from "next/head";
import { serialize } from "next-mdx-remote/serialize";
import { TwitterTweetEmbed } from "react-twitter-embed";
import InstagramEmbed from "react-instagram-embed";

interface MemoProps {
  frontMatter: {
    title: string;
    date: string;
    excerpt?: string;
    ogImage?: string;
  };
  mdxSource: MDXRemoteProps;
}

function TweetEmbed({ tweetId }: { tweetId: string }) {
  return (
    <div
      style={{
        margin: "32px 0",
        display: "flex",
        justifyContent: "center",
        maxWidth: "100%",
        overflow: "hidden",
      }}
    >
      <TwitterTweetEmbed
        tweetId={tweetId}
        options={{
          theme: "dark",
          width: "100%",
          align: "center",
          dnt: true,
        }}
      />
    </div>
  );
}

function CustomInstagramEmbed({ url }: { url: string }) {
  return (
    <div
      style={{
        margin: "32px 0",
        display: "flex",
        justifyContent: "center",
        maxWidth: "100%",
        overflow: "hidden",
      }}
    >
      <InstagramEmbed
        url={url}
        clientAccessToken="YOUR_CLIENT_ACCESS_TOKEN"
        maxWidth={500}
        hideCaption={false}
        containerTagName="div"
        protocol=""
        injectScript
        onLoading={() => {}}
        onSuccess={() => {}}
        onAfterRender={() => {}}
        onFailure={() => {}}
      />
    </div>
  );
}

const mdxComponents = {
  h1: (props: any) => (
    <h1
      className="rainbow-text memo-rainbow-h1"
      style={{
        fontSize: "2em",
        fontWeight: 700,
        letterSpacing: "-0.02em",
        background:
          "linear-gradient(90deg, #A78BFA 0%, #60A5FA 100%)",
        backgroundSize: "200% 100%",
        WebkitBackgroundClip: "text",
        WebkitTextFillColor: "transparent",
        backgroundClip: "text",
        lineHeight: "1.3",
        marginTop: "48px",
        marginBottom: "24px",
      }}
      {...props}
    />
  ),
  h2: (props: any) => (
    <h2
      className="rainbow-text memo-rainbow-h2"
      style={{
        fontSize: "1.5em",
        fontWeight: 700,
        letterSpacing: "-0.02em",
        background:
          "linear-gradient(90deg, #A78BFA 0%, #60A5FA 100%)",
        backgroundSize: "200% 100%",
        WebkitBackgroundClip: "text",
        WebkitTextFillColor: "transparent",
        backgroundClip: "text",
        lineHeight: "1.4",
        marginTop: "40px",
        marginBottom: "20px",
      }}
      {...props}
    />
  ),
  h3: (props: any) => (
    <h3
      className="rainbow-text memo-rainbow-h3"
      style={{
        fontSize: "1.25em",
        fontWeight: 700,
        letterSpacing: "-0.02em",
        background:
          "linear-gradient(90deg, #A78BFA 0%, #60A5FA 100%)",
        backgroundSize: "200% 100%",
        WebkitBackgroundClip: "text",
        WebkitTextFillColor: "transparent",
        backgroundClip: "text",
        lineHeight: "1.4",
        marginTop: "32px",
        marginBottom: "16px",
      }}
      {...props}
    />
  ),
  p: (props: any) => (
    <p
      className="memo-paragraph"
      style={{
        fontSize: "1.0625em",
        color: "rgba(255, 255, 255, 0.9)",
        lineHeight: "1.75",
        marginTop: "0",
        marginBottom: "24px",
        fontWeight: 400,
      }}
      {...props}
    />
  ),
  ul: (props: any) => (
    <ul
      className="memo-list"
      style={{
        paddingLeft: "24px",
        marginBottom: "24px",
      }}
      {...props}
    />
  ),
  ol: (props: any) => (
    <ol
      className="memo-list"
      style={{
        paddingLeft: "24px",
        marginBottom: "24px",
      }}
      {...props}
    />
  ),
  li: (props: any) => (
    <li
      className="memo-list-item"
      style={{
        fontSize: "1.0625em",
        color: "rgba(255, 255, 255, 0.9)",
        lineHeight: "1.75",
        marginBottom: "8px",
        fontWeight: 400,
      }}
      {...props}
    />
  ),
  a: (props: any) => (
    <a
      style={{
        color: "rgba(255, 255, 255, 0.6)",
        textDecoration: "none",
        transition: "color 0.2s ease",
        borderBottom: "1px solid transparent",
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.color = "rgba(255, 255, 255, 0.9)";
        e.currentTarget.style.borderBottom =
          "1px solid rgba(255, 255, 255, 0.3)";
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.color = "rgba(255, 255, 255, 0.6)";
        e.currentTarget.style.borderBottom = "1px solid transparent";
      }}
      {...props}
    />
  ),
  blockquote: (props: any) => (
    <blockquote
      className="memo-blockquote"
      style={{
        borderLeft: "3px solid rgba(255, 255, 255, 0.2)",
        paddingLeft: "20px",
        margin: "32px 0",
        fontStyle: "italic",
        color: "rgba(255, 255, 255, 0.85)",
      }}
      {...props}
    />
  ),
  code: (props: any) => (
    <code
      className="memo-code-inline"
      style={{
        backgroundColor: "rgba(255, 255, 255, 0.1)",
        padding: "3px 6px",
        borderRadius: "4px",
        fontSize: "0.9375em",
        color: "#FFFFFF",
        fontFamily:
          '"SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace',
        border: "1px solid rgba(255, 255, 255, 0.1)",
      }}
      {...props}
    />
  ),
  pre: (props: any) => (
    <pre
      className="memo-code-block"
      style={{
        backgroundColor: "rgba(0, 0, 0, 0.4)",
        color: "#fafafa",
        padding: "20px",
        borderRadius: "12px",
        overflow: "auto",
        marginBottom: "24px",
        fontSize: "0.875em",
        lineHeight: "1.6",
        border: "1px solid rgba(255, 255, 255, 0.1)",
        backdropFilter: "blur(10px)",
        WebkitBackdropFilter: "blur(10px)",
      }}
      {...props}
    />
  ),
  table: (props: any) => (
    <div style={{ overflowX: "auto", marginBottom: "24px" }}>
      <table
        style={{
          width: "100%",
          borderCollapse: "collapse",
          fontSize: "1em",
        }}
        {...props}
      />
    </div>
  ),
  thead: (props: any) => (
    <thead
      style={{
        borderBottom: "2px solid rgba(255, 255, 255, 0.2)",
      }}
      {...props}
    />
  ),
  tbody: (props: any) => <tbody {...props} />,
  tr: (props: any) => (
    <tr
      style={{
        borderBottom: "1px solid rgba(255, 255, 255, 0.05)",
      }}
      {...props}
    />
  ),
  th: (props: any) => (
    <th
      className="memo-table-cell"
      style={{
        textAlign: "left",
        padding: "12px 16px",
        fontWeight: 600,
        color: "#FFFFFF",
        fontSize: "0.9375em",
      }}
      {...props}
    />
  ),
  td: (props: any) => (
    <td
      className="memo-table-cell"
      style={{
        padding: "12px 16px",
        color: "rgba(255, 255, 255, 0.9)",
      }}
      {...props}
    />
  ),
  hr: (props: any) => (
    <hr
      className="memo-horizontal-rule"
      style={{
        border: "none",
        borderTop: "1px solid rgba(255, 255, 255, 0.1)",
        margin: "48px 0",
      }}
      {...props}
    />
  ),
  img: (props: any) => (
    <img
      className="memo-image"
      style={{
        maxWidth: "100%",
        height: "auto",
        borderRadius: "12px",
        margin: "32px 0",
        border: "1px solid rgba(255, 255, 255, 0.1)",
        boxShadow: "0 8px 32px rgba(0, 0, 0, 0.3)",
      }}
      {...props}
      alt={props.alt || ""}
    />
  ),
  TweetEmbed,
  InstagramEmbed: CustomInstagramEmbed,
  EmailButton: () => (
    <div
      style={{ display: "flex", justifyContent: "center", marginTop: "32px" }}
    >
      <a
        href="mailto:allenleexyz@gmail.com"
        style={{
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "0.8em 2em",
          fontSize: "1.1em",
          fontWeight: 700,
          color: "#FFFFFF",
          background:
            "linear-gradient(135deg, rgba(92, 45, 164, 1) 0%, rgba(124, 58, 237, 1) 14.3%, rgba(139, 92, 246, 1) 28.6%, rgba(59, 130, 246, 1) 42.9%, rgba(34, 197, 94, 1) 57.1%, rgba(251, 146, 60, 1) 71.4%, rgba(14, 165, 233, 1) 85.7%, rgba(56, 189, 248, 1) 100%)",
          backgroundSize: "200% 200%",
          backdropFilter: "blur(30px) saturate(1.8)",
          WebkitBackdropFilter: "blur(30px) saturate(1.8)",
          border: "2px solid rgba(255, 255, 255, 0.4)",
          borderRadius: "50px",
          boxShadow:
            "0 8px 32px rgba(139, 92, 246, 0.6), 0 4px 16px rgba(219, 39, 119, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.25), inset 0 2px 0 rgba(255, 255, 255, 0.5), inset 0 -2px 0 rgba(0, 0, 0, 0.1)",
          cursor: "pointer",
          transition:
            "transform 0.3s ease-out, box-shadow 0.3s ease-out, backdrop-filter 0.3s ease-out",
          fontFamily: "inherit",
          letterSpacing: "0.03em",
          textShadow: "0 1px 2px rgba(0, 0, 0, 0.3)",
          position: "relative",
          overflow: "hidden",
          textDecoration: "none",
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = "translateY(-4px) scale(1.08)";
          e.currentTarget.style.boxShadow =
            "0 20px 60px rgba(139, 92, 246, 0.9), 0 15px 40px rgba(34, 197, 94, 0.7), 0 0 0 3px rgba(255, 255, 255, 0.4), inset 0 2px 0 rgba(255, 255, 255, 0.6), 0 0 80px rgba(251, 146, 60, 0.6), 0 0 120px rgba(59, 130, 246, 0.4)";
          e.currentTarget.style.backdropFilter = "blur(40px) saturate(2.2)";
          e.currentTarget.style.borderColor = "rgba(255, 255, 255, 0.6)";
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = "translateY(0) scale(1)";
          e.currentTarget.style.boxShadow =
            "0 8px 32px rgba(139, 92, 246, 0.6), 0 4px 16px rgba(219, 39, 119, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.25), inset 0 2px 0 rgba(255, 255, 255, 0.5), inset 0 -2px 0 rgba(0, 0, 0, 0.1)";
          e.currentTarget.style.backdropFilter = "blur(30px) saturate(1.8)";
          e.currentTarget.style.borderColor = "rgba(255, 255, 255, 0.4)";
        }}
      >
        allenleexyz@gmail.com
      </a>
    </div>
  ),
  TestFlightButton: () => (
    <div
      style={{ display: "flex", justifyContent: "center", marginTop: "32px", marginBottom: "32px" }}
    >
      <a
        href="https://testflight.apple.com/join/ATvtBUZH"
        target="_blank"
        rel="noopener noreferrer"
        style={{
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "0.8em 2em",
          fontSize: "1.1em",
          fontWeight: 700,
          color: "#FFFFFF",
          background:
            "linear-gradient(135deg, rgba(92, 45, 164, 1) 0%, rgba(124, 58, 237, 1) 14.3%, rgba(139, 92, 246, 1) 28.6%, rgba(59, 130, 246, 1) 42.9%, rgba(34, 197, 94, 1) 57.1%, rgba(251, 146, 60, 1) 71.4%, rgba(14, 165, 233, 1) 85.7%, rgba(56, 189, 248, 1) 100%)",
          backgroundSize: "200% 200%",
          backdropFilter: "blur(30px) saturate(1.8)",
          WebkitBackdropFilter: "blur(30px) saturate(1.8)",
          border: "2px solid rgba(255, 255, 255, 0.4)",
          borderRadius: "50px",
          boxShadow:
            "0 8px 32px rgba(139, 92, 246, 0.6), 0 4px 16px rgba(219, 39, 119, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.25), inset 0 2px 0 rgba(255, 255, 255, 0.5), inset 0 -2px 0 rgba(0, 0, 0, 0.1)",
          cursor: "pointer",
          transition:
            "transform 0.3s ease-out, box-shadow 0.3s ease-out, backdrop-filter 0.3s ease-out",
          fontFamily: "inherit",
          letterSpacing: "0.03em",
          textShadow: "0 1px 2px rgba(0, 0, 0, 0.3)",
          position: "relative",
          overflow: "hidden",
          textDecoration: "none",
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = "translateY(-4px) scale(1.08)";
          e.currentTarget.style.boxShadow =
            "0 20px 60px rgba(139, 92, 246, 0.9), 0 15px 40px rgba(34, 197, 94, 0.7), 0 0 0 3px rgba(255, 255, 255, 0.4), inset 0 2px 0 rgba(255, 255, 255, 0.6), 0 0 80px rgba(251, 146, 60, 0.6), 0 0 120px rgba(59, 130, 246, 0.4)";
          e.currentTarget.style.backdropFilter = "blur(40px) saturate(2.2)";
          e.currentTarget.style.borderColor = "rgba(255, 255, 255, 0.6)";
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = "translateY(0) scale(1)";
          e.currentTarget.style.boxShadow =
            "0 8px 32px rgba(139, 92, 246, 0.6), 0 4px 16px rgba(219, 39, 119, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.25), inset 0 2px 0 rgba(255, 255, 255, 0.5), inset 0 -2px 0 rgba(0, 0, 0, 0.1)";
          e.currentTarget.style.backdropFilter = "blur(30px) saturate(1.8)";
          e.currentTarget.style.borderColor = "rgba(255, 255, 255, 0.4)";
        }}
      >
         Download TestFlight
      </a>
    </div>
  ),
};

export default function Memo({ frontMatter, mdxSource }: MemoProps) {
  const ogImage = frontMatter.ogImage || "/og/default.png";
  const description =
    frontMatter.excerpt ||
    "AirPosture Blog - Thoughts, updates, and insights from the team";
  const url = "https://airposture.pro/memo";

  return (
    <>
      <Head>
        <meta property="og:title" content={frontMatter.title} />
        <meta property="og:description" content={description} />
        <meta property="og:image" content={ogImage} />
        <meta property="og:url" content={url} />
        <meta property="og:type" content="article" />
        <meta property="og:site_name" content="AirPosture" />

        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={frontMatter.title} />
        <meta name="twitter:description" content={description} />
        <meta name="twitter:image" content={ogImage} />

        <meta name="description" content={description} />
      </Head>

      <style jsx global>{`
        body {
          background: #000000;
        }

        @media (max-width: 639px) {
          .memo-content-container {
            padding: 40px 16px 60px !important;
          }

          .memo-article-card {
            padding: 24px 20px !important;
          }

          .memo-article-title {
            font-size: 1.75em !important;
          }

          .memo-content-area {
            font-size: 1em !important;
          }
        }

        @media (min-width: 640px) and (max-width: 1023px) {
          .memo-content-container {
            padding: 60px 20px 80px !important;
          }

          .memo-article-card {
            padding: 36px 24px !important;
          }

          .memo-article-title {
            font-size: 2.25em !important;
          }
        }

        @media (max-width: 639px) {
          .memo-rainbow-h1 {
            font-size: 1.5em !important;
            margin-top: 32px !important;
            margin-bottom: 16px !important;
          }

          .memo-rainbow-h2 {
            font-size: 1.25em !important;
            margin-top: 28px !important;
            margin-bottom: 14px !important;
          }

          .memo-rainbow-h3 {
            font-size: 1.125em !important;
            margin-top: 24px !important;
            margin-bottom: 12px !important;
          }

          .memo-paragraph {
            font-size: 1em !important;
            margin-bottom: 20px !important;
          }

          .memo-list {
            padding-left: 20px !important;
            margin-bottom: 20px !important;
          }

          .memo-list-item {
            font-size: 1em !important;
            margin-bottom: 6px !important;
          }

          .memo-blockquote {
            padding-left: 16px !important;
            margin: 24px 0 !important;
          }

          .memo-code-inline {
            font-size: 0.875em !important;
            padding: 2px 5px !important;
          }

          .memo-code-block {
            padding: 16px !important;
            font-size: 0.8125em !important;
            margin-bottom: 20px !important;
          }

          .memo-table-cell {
            padding: 10px 12px !important;
            font-size: 0.875em !important;
          }

          .memo-image {
            margin: 24px 0 !important;
            border-radius: 8px !important;
          }

          .memo-horizontal-rule {
            margin: 36px 0 !important;
          }
        }

        @media (min-width: 640px) and (max-width: 1023px) {
          .memo-rainbow-h1 {
            font-size: 1.75em !important;
            margin-top: 40px !important;
            margin-bottom: 20px !important;
          }

          .memo-rainbow-h2 {
            font-size: 1.375em !important;
            margin-top: 34px !important;
            margin-bottom: 17px !important;
          }

          .memo-rainbow-h3 {
            font-size: 1.1875em !important;
            margin-top: 28px !important;
            margin-bottom: 14px !important;
          }

          .memo-paragraph {
            font-size: 1.03125em !important;
            margin-bottom: 22px !important;
          }

          .memo-list {
            padding-left: 22px !important;
            margin-bottom: 22px !important;
          }

          .memo-list-item {
            font-size: 1.03125em !important;
            margin-bottom: 7px !important;
          }
        }
      `}</style>

      <div
        className="memo-content-container"
        style={{
          maxWidth: "720px",
          margin: "0 auto",
          padding: "80px 24px 100px",
          fontFamily:
            "'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
          position: "relative",
        }}
      >
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

        <a
          href="/"
          style={{
            position: "fixed",
            top: "24px",
            left: "24px",
            zIndex: 1000,
          }}
        >
          <img
            src="/air.png"
            alt="AirPosture"
            style={{
              width: "80px",
              height: "auto",
            }}
          />
        </a>

        <article
          className="memo-article-card"
          style={{
            padding: "48px",
            borderRadius: "30px",
            background: "rgba(0, 0, 0, 0.2)",
            backdropFilter: "blur(20px)",
            WebkitBackdropFilter: "blur(20px)",
            border: "1px solid rgba(255, 255, 255, 0.1)",
            boxShadow: "0 8px 32px rgba(31, 38, 135, 0.15)",
            position: "relative",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background:
                "radial-gradient(circle at 30% 70%, rgba(15, 29, 59, 0.18) 0%, transparent 50%)",
              pointerEvents: "none",
              zIndex: 0,
            }}
          />

          <div style={{ position: "relative", zIndex: 1 }}>
            <header style={{ marginBottom: "48px" }}>
              <h1
                className="memo-article-title"
                style={{
                  fontSize: "2.75em",
                  fontWeight: 700,
                  letterSpacing: "-0.02em",
                  background:
                    "linear-gradient(135deg, #FFFFFF 0%, #F5F5F5 25%, #E8E8E8 50%, #F5F5F5 75%, #FFFFFF 100%)",
                  WebkitBackgroundClip: "text",
                  WebkitTextFillColor: "transparent",
                  backgroundClip: "text",
                  color: "transparent",
                  textShadow: "0 2px 10px rgba(0, 0, 0, 0.3)",
                  lineHeight: "1.2",
                  marginBottom: "20px",
                }}
              >
                {frontMatter.title}
              </h1>
            </header>

            <div className="memo-content-area" style={{ fontSize: "1.0625em" }}>
              <MDXRemote {...mdxSource} components={mdxComponents} />
            </div>
          </div>
        </article>
      </div>
    </>
  );
}

export async function getStaticProps() {
  const filePath = path.join("content/memo", "index.mdx");
  const fileContent = fs.readFileSync(filePath, "utf-8");
  const { data: frontMatter, content } = matter(fileContent);

  const mdxSource = await serialize(content);

  return {
    props: {
      frontMatter,
      mdxSource,
    },
  };
}
