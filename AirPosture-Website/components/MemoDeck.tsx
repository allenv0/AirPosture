import { useState, useEffect, useCallback } from "react";
import styles from "../styles/Deck.module.css";

interface Slide {
  id: number;
  title: string;
  content: string[];
  image?: string;
  images?: string[];
  hasEmailButton?: boolean;
}

const slides: Slide[] = [
  {
    id: 0,
    title: "AirPosture",
    content: ["AirPods as an AI Posture Assistant"],
    image: "/Cards/real-time.png",
  },
  {
    id: 1,
    title: "The Product",
    content: [
      "Unlocks the hidden sensors in your AirPods, turning them into a real-time posture coach for work and workouts on iOS",
      "Embodied AI posture and movement coach",
      "Helps people sit straighter at work",
      "Better form during workouts",
    ],
    image: "/demo-landing.gif",
  },
  {
    id: 2,
    title: "Early Traction",
    content: [
      "1.3K users, 7.88K+ sessions in 12 days",
      "Zero marketing spend",
      "500K+ organic views across platforms",
      "Creators making content for free",
    ],
    images: ["/media/media-all2.png", "/media/media-all.png"],
  },
  {
    id: 4,
    title: "Vision",
    content: [
      "Posture tracking & 3D movement audio guidance",
      "Marketplace of activity coaching models",
      "Fully on-device health AI",
    ],
    images: ["/3d.png", "/media/ir2.jpeg"],
  },
  {
    id: 5,
    title: "Moats",
    content: [
      "Auto-Activity Learning - on-device models",
      "Creator & Model Marketplace - network effects",
      "Fully on-device, privacy-first",
    ],
    image: "/Cards/bear-running2.gif",
  },
  {
    id: 6,
    title: "Founder",
    content: [
      "Allen Lee",
      "iOS & macOS design engineer",
      "Former AI leader at Conde Nast",
    ],
    image: "/media/IMG_1913.JPG",
    hasEmailButton: true,
  },
];

const TRANSITION_MS = 300;

function parseSlideHash(hash: string): number | null {
  if (!hash.startsWith("#slide-")) {
    return null;
  }

  const maybeSlide = Number.parseInt(hash.replace("#slide-", ""), 10);
  if (Number.isNaN(maybeSlide)) {
    return null;
  }

  if (maybeSlide < 0 || maybeSlide >= slides.length) {
    return null;
  }

  return maybeSlide;
}

export default function MemoDeck() {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [isTransitioning, setIsTransitioning] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const [showTapHint, setShowTapHint] = useState(false);
  const [pausedSlides, setPausedSlides] = useState<Set<number>>(new Set());

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth <= 768);
    checkMobile();
    window.addEventListener("resize", checkMobile);
    return () => window.removeEventListener("resize", checkMobile);
  }, []);

  useEffect(() => {
    const hashSlide = parseSlideHash(window.location.hash);
    if (hashSlide !== null) {
      setCurrentSlide(hashSlide);
    } else {
      window.history.replaceState(null, "", "#slide-0");
    }

    const handleHashChange = () => {
      const next = parseSlideHash(window.location.hash);
      if (next !== null) {
        setCurrentSlide((prev) => (prev === next ? prev : next));
      }
    };

    window.addEventListener("hashchange", handleHashChange);
    return () => window.removeEventListener("hashchange", handleHashChange);
  }, []);

  useEffect(() => {
    if (!isMobile) {
      return;
    }

    const hasSeenHint = localStorage.getItem("deck-nav-hint");
    if (hasSeenHint) {
      return;
    }

    setShowTapHint(true);
    const timer = window.setTimeout(() => {
      setShowTapHint(false);
      localStorage.setItem("deck-nav-hint", "true");
    }, 4000);

    return () => window.clearTimeout(timer);
  }, [isMobile]);

  const goToSlide = useCallback(
    (index: number) => {
      if (isTransitioning) {
        return;
      }

      if (index < 0 || index >= slides.length || index === currentSlide) {
        return;
      }

      setIsTransitioning(true);
      setCurrentSlide(index);

      const nextHash = `#slide-${index}`;
      if (window.location.hash !== nextHash) {
        window.location.hash = nextHash;
      }

      window.setTimeout(() => setIsTransitioning(false), TRANSITION_MS);
    },
    [currentSlide, isTransitioning],
  );

  const nextSlide = useCallback(() => {
    goToSlide(currentSlide + 1);
  }, [currentSlide, goToSlide]);

  const prevSlide = useCallback(() => {
    goToSlide(currentSlide - 1);
  }, [currentSlide, goToSlide]);

  const togglePause = useCallback((slideId: number, e: React.MouseEvent) => {
    e.stopPropagation();
    setPausedSlides((prev) => {
      const next = new Set(prev);
      if (next.has(slideId)) {
        next.delete(slideId);
      } else {
        next.add(slideId);
      }
      return next;
    });
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight" || e.key === "ArrowDown" || e.key === " ") {
        e.preventDefault();
        nextSlide();
        return;
      }

      if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
        e.preventDefault();
        prevSlide();
        return;
      }

      if (e.key === "Home") {
        e.preventDefault();
        goToSlide(0);
        return;
      }

      if (e.key === "End") {
        e.preventDefault();
        goToSlide(slides.length - 1);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [goToSlide, nextSlide, prevSlide]);

  return (
    <div className={styles.deck} role="region" aria-label="AirPosture pitch deck">
      <div className={styles.background} aria-hidden="true" />

      {isMobile && showTapHint && (
        <div className={styles.tapHint}>
          <svg
            className={styles.tapIcon}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            aria-hidden="true"
          >
            <path d="M5 12h14" />
            <path d="m12 5 7 7-7 7" />
          </svg>
          <span>Use Next and Previous to move slides</span>
        </div>
      )}

      <a href="/" className={styles.homeLink}>
        <img src="/air.png" alt="AirPosture home" className={styles.logo} />
      </a>

      <div className={styles.viewport}>
        {slides.map((slide, index) => {
          const isActive = index === currentSlide;
          const shouldLoadMedia = Math.abs(index - currentSlide) <= 1;

          return (
            <section
              key={slide.id}
              className={`${styles.slide} ${isActive ? styles.slideActive : ""}`}
              style={{ transform: `translateX(${(index - currentSlide) * 100}%)` }}
              aria-hidden={!isActive}
              aria-label={`Slide ${index + 1} of ${slides.length}: ${slide.title}`}
            >
              <div className={`${styles.slideInner} ${isActive ? styles.slideInnerAnimate : ""}`}>
                <div
                  className={`${styles.copy} ${slide.image || slide.images ? "" : styles.copyFull}`}
                >
                  <h2 className={styles.title}>{slide.title}</h2>
                  <ul className={styles.bullets}>
                    {slide.content.map((bullet, i) => (
                      <li
                        key={`${slide.id}-${i}`}
                        className={`${styles.bullet} ${i === 0 ? styles.bulletLead : ""}`}
                      >
                        <span className={styles.bulletDot} aria-hidden="true" />
                        {bullet}
                      </li>
                    ))}
                  </ul>

                  {slide.hasEmailButton && (
                    <div className={styles.memoButtonWrap}>
                      <a href="/memo" className={styles.memoButton}>
                        Full Memo
                      </a>
                    </div>
                  )}
                </div>

                {slide.images ? (
                  <div className={styles.mediaColumn}>
                    {slide.images.map((img, idx) => (
                      <div
                        key={`${slide.id}-${img}-${idx}`}
                        className={styles.mediaCard}
                        onClick={(e) => togglePause(slide.id, e)}
                      >
                        {shouldLoadMedia ? (
                          <img
                            src={img}
                            alt={`${slide.title} visual ${idx + 1}`}
                            className={`${styles.media} ${styles.mediaStacked}`}
                            loading={isActive ? "eager" : "lazy"}
                            decoding="async"
                            style={{ animationPlayState: pausedSlides.has(slide.id) ? 'paused' : 'running' }}
                          />
                        ) : (
                          <div
                            className={`${styles.mediaPlaceholder} ${styles.mediaPlaceholderStacked}`}
                            aria-hidden="true"
                          />
                        )}
                      </div>
                    ))}
                  </div>
                ) : slide.image ? (
                  <div className={styles.mediaColumn}>
                    <div
                      className={styles.mediaCard}
                      onClick={(e) => togglePause(slide.id, e)}
                    >
                      {shouldLoadMedia ? (
                        <img
                          src={slide.image}
                          alt={`${slide.title} visual`}
                          className={styles.media}
                          loading={isActive ? "eager" : "lazy"}
                          decoding="async"
                          style={{ animationPlayState: pausedSlides.has(slide.id) ? 'paused' : 'running' }}
                        />
                      ) : (
                        <div className={styles.mediaPlaceholder} aria-hidden="true" />
                      )}
                    </div>
                  </div>
                ) : null}
              </div>
            </section>
          );
        })}
      </div>

      <nav className={styles.dotNav} aria-label="Slide navigation">
        {slides.map((slide, index) => (
          <button
            key={slide.id}
            type="button"
            className={styles.dotButton}
            onClick={() => goToSlide(index)}
            aria-label={`Go to slide ${index + 1}: ${slide.title}`}
            aria-current={index === currentSlide ? "true" : undefined}
          >
            <span
              className={`${styles.dotIndicator} ${index === currentSlide ? styles.dotIndicatorActive : ""}`}
              aria-hidden="true"
            />
            <span className={styles.dotTooltip}>{slide.title}</span>
            <span className={styles.srOnly}>{slide.title}</span>
          </button>
        ))}
      </nav>

      <div className={styles.controls}>
        <button
          type="button"
          className={styles.navButton}
          onClick={prevSlide}
          disabled={currentSlide === 0}
          aria-label="Previous slide"
        >
          Previous
        </button>

        <p className={styles.progress} aria-live="polite" aria-atomic="true">
          {currentSlide + 1} / {slides.length}
        </p>

        <button
          type="button"
          className={styles.navButton}
          onClick={nextSlide}
          disabled={currentSlide === slides.length - 1}
          aria-label="Next slide"
        >
          Next
        </button>
      </div>
    </div>
  );
}
