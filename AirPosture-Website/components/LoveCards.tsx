import React, { useState, useEffect, useRef } from "react";
import Image from "next/image";
import styles from "./LoveCards.module.css";

interface LoveCard {
  id: number;
  name: string;
  comment: string;
  rating: number;
  location: string;
  verified: boolean;
  avatar: string;
  weeksUsing?: number;
  link?: string;
}

function LoveCards() {
  const containerRef = useRef<HTMLDivElement>(null);
  const animationRef = useRef<number>();
  const scrollPositionRef = useRef(0);

  const containerRef2 = useRef<HTMLDivElement>(null);
  const animationRef2 = useRef<number>();
  const scrollPositionRef2 = useRef(0);

  const originalCards: LoveCard[] = [
    {
      id: 1,
      name: "Sarah",
      comment:
        "Testing out this right now - and i can tell you: You've got a customer here confirmed. AMAZING APP!",
      rating: 5,
      location: "AirPod Pro 2",
      verified: true,
      avatar: "/avatars/alice.png",
      weeksUsing: 12,
      link: "https://www.reddit.com/r/macapps/comments/1kztuya/airpods_as_a_posture_coach_on_mac/",
    },
    {
      id: 2,
      name: "Marcus",
      comment:
        "Just tried this. This is so amazing. I have been struggling with stiff neck for a while now due to my posture.",
      rating: 5,
      location: "AirPod 4",
      verified: true,
      avatar: "/avatars/b.png",
      weeksUsing: 8,
      link: "https://www.reddit.com/r/iosapps/comments/1m4isld/turn_your_airpods_into_a_realtime_posture_coach/",
    },
    {
      id: 3,
      name: "Emma",
      comment: "Game changer. My neck and back pain decreased significantly.",
      rating: 5,
      location: "AirPod Pro 3",
      verified: true,
      avatar: "/avatars/c.png",
      weeksUsing: 16,
      link: "https://www.reddit.com/r/macapps/comments/1kztuya/airpods_as_a_posture_coach_on_mac/",
    },
    {
      id: 4,
      name: "David",
      comment: "Simple and effective.",
      rating: 5,
      location: "AirPod Max",
      verified: true,
      avatar: "/avatars/tim.png",
      weeksUsing: 10,
      link: "https://www.reddit.com/r/iosapps/comments/1m4isld/turn_your_airpods_into_a_realtime_posture_coach/",
    },
    {
      id: 5,
      name: "Lisa",
      comment: "Calming animations became second nature. Feel more confident!",
      rating: 5,
      location: "AirPod Pro 2",
      verified: true,
      avatar: "/avatars/alice.png",
      weeksUsing: 14,
      link: "https://www.reddit.com/r/macapps/comments/1kztuya/airpods_as_a_posture_coach_on_mac/",
    },
    {
      id: 6,
      name: "James",
      comment: "I really love your app",
      rating: 5,
      location: "AirPod 4",
      verified: true,
      avatar: "/avatars/allen.png",
      weeksUsing: 6,
      link: "https://www.reddit.com/r/iosapps/comments/1m4isld/turn_your_airpods_into_a_realtime_posture_coach/",
    },
    {
      id: 7,
      name: "Kim",
      comment: "Gentle reminders is a great feature",
      rating: 5,
      location: "AirPod Pro 3",
      verified: true,
      avatar: "/avatars/b.png",
      weeksUsing: 20,
      link: "https://www.reddit.com/r/macapps/comments/1kztuya/airpods_as_a_posture_coach_on_mac/",
    },
    {
      id: 8,
      name: "Oliver",
      comment:
        "Need more novel app ideas like this and way less vibe coded $4- $39.99/ mth apps that all do the same crap.",
      rating: 5,
      location: "AirPod Max",
      verified: true,
      avatar: "/avatars/b.png",
      weeksUsing: 11,
      link: "https://www.reddit.com/r/iosapps/comments/1m4isld/turn_your_airpods_into_a_realtime_posture_coach/",
    },
    {
      id: 9,
      name: "Isabella",
      comment: "Premium quality app",
      rating: 5,
      location: "AirPod 4",
      verified: true,
      avatar: "/avatars/b.png",
      weeksUsing: 9,
      link: "https://www.reddit.com/r/macapps/comments/1kztuya/airpods_as_a_posture_coach_on_mac/",
    },
  ];

  const mediaCards: LoveCard[] = [
    {
      id: 10,
      name: "Manuel Prol",
      comment: "La app se llama AirPosture y está en pruebas en Testflight ✨🙌",
      rating: 5,
      location: "318 ❤️ on Instagram",
      verified: true,
      avatar: "/media/s.jpg",
      weeksUsing: 7,
      link: "https://www.instagram.com/reel/DRkq2zzDSmn/?utm_source=ig_web_copy_link&igsh=MzRlODBiNWFlZA==",
    },
    {
      id: 11,
      name: "Applesfera",
      comment: "Esta app promete evitar las malas posturas gracias a los AirPods. Llevo años con dolores de espalda, así que tenía que probarla",
      rating: 5,
      location: "100K+ Views",
      verified: true,
      avatar: "/media/ap.jpg",
      link: "https://www.applesfera.com/aplicaciones-ios/esta-app-promete-evitar-malas-posturas-gracias-a-airpods-llevo-anos-dolores-espalda-asi-que-tenia-que-probarla",
    },
    {
      id: 12,
      name: "Tom Dörr",
      comment: "Turns AirPods into a real-time AI posture coach",
      rating: 5,
      location: "1.3K ❤️ on X",
      verified: true,
      avatar: "/media/t.jpg",

      link: "https://x.com/tom_doerr/status/1993432606801535465",
    },
        {
      id: 13,
      name: "ROZETKED",
      comment: "У проекта открытый исходный код, репозиторий доступен на GitHub.",
      rating: 5,
      location: "100K+ Views",
      verified: true,
      avatar: "/media/r.jpg",

      link: "https://rozetked.me/news/42960-entuziast-vypustil-airposture-utilitu-dlya-slezheniya-za-osankoy-cherez-airpods",
    },
  ];

  const reversedMediaCards = [...mediaCards].reverse();

  useEffect(() => {
    const animate = () => {
      if (containerRef.current) {
        scrollPositionRef.current += 0.5;
        const cardWidth = 320;
        const gap = 16;
        const totalWidth = (cardWidth + gap) * originalCards.length;
        
        if (scrollPositionRef.current >= totalWidth) {
          scrollPositionRef.current = 0;
        }
        
        containerRef.current.style.transform = `translateX(-${scrollPositionRef.current}px)`;
      }
      animationRef.current = requestAnimationFrame(animate);
    };

    animationRef.current = requestAnimationFrame(animate);

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [originalCards.length]);

  useEffect(() => {
    const animate2 = () => {
      if (containerRef2.current) {
        scrollPositionRef2.current += 0.5;
        const cardWidth = 320;
        const gap = 16;
        const totalWidth = (cardWidth + gap) * mediaCards.length;
        
        if (scrollPositionRef2.current >= totalWidth) {
          scrollPositionRef2.current = 0;
        }
        
        containerRef2.current.style.transform = `translateX(-${scrollPositionRef2.current}px)`;
      }
      animationRef2.current = requestAnimationFrame(animate2);
    };

    animationRef2.current = requestAnimationFrame(animate2);

    return () => {
      if (animationRef2.current) {
        cancelAnimationFrame(animationRef2.current);
      }
    };
  }, [mediaCards.length]);

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <div key={i} className={styles.starContainer}>
        <div
          className={`${styles.star} ${i < rating ? styles.starFilled : ""}`}
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
              fill="currentColor"
            />
          </svg>
        </div>
      </div>
    ));
  };

  return (
    <div className={styles.loveCardsContainer}>
      <h1 className={`${styles.featuresLabel} silver-gradient-text`}>
        ❤️ by Thousands
      </h1>

      {/* First row - Users */}
      <div className={styles.cardsGrid}>
        <div
          ref={containerRef}
          className={styles.cardsGridInner}
        >
          {[...originalCards, ...originalCards, ...originalCards].map((card, index) => (
            <div
              key={`${card.id}-${index}`}
              className={styles.loveCard}
              style={{
                animationDelay: `${(index % originalCards.length) * 0.2}s`,
              }}
              onClick={() => {
              if (card.link) {
                window.open(card.link, "_blank", "noopener,noreferrer");
              }
            }}
          >
            <div className={styles.cardHeader}>
              <div className={styles.userInfo}>
                <div className={styles.avatar}>
                  <Image
                    src={card.avatar}
                    alt={card.name}
                    width={48}
                    height={48}
                  />
                </div>
                <div className={styles.userDetails}>
                  <div className={styles.userName}>
                    {card.name}
                    {card.verified && (
                      <svg
                        className={styles.verifiedBadge}
                        viewBox="0 0 24 24"
                        fill="currentColor"
                      >
                        <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                      </svg>
                    )}
                  </div>
                  <div className={styles.userLocation}>
                    {card.location}
                    {card.weeksUsing && (
                      <span className={styles.weeksUsing}>
                        {" "}
                        • {card.weeksUsing} sessions/day
                      </span>
                    )}
                  </div>
                </div>
              </div>
              <div className={styles.starsContainer}>
                {renderStars(card.rating)}
              </div>
            </div>

            <div className={styles.comment}>
              <span className={styles.quoteMark}>"</span>
              {card.comment}
              <span className={styles.quoteMark}>"</span>
            </div>
          </div>
        ))}
        </div>
      </div>

      <div className={styles.sectionSubtitle}>
        Featured In Media
      </div>

      {/* Second row - Media */}
      <div className={styles.cardsGrid}>
        <div ref={containerRef2} className={styles.cardsGridInner}>
          {[...reversedMediaCards, ...reversedMediaCards, ...reversedMediaCards].map((card, index) => (
            <div
              key={`${card.id}-${index}`}
              className={styles.loveCard}
              style={{
                animationDelay: `${index * 0.2}s`,
              }}
              onClick={() => {
              if (card.link) {
                window.open(card.link, "_blank", "noopener,noreferrer");
              }
            }}
          >
            <div className={styles.cardHeader}>
              <div className={styles.userInfo}>
                <div className={styles.avatar}>
                  <Image
                    src={card.avatar}
                    alt={card.name}
                    width={48}
                    height={48}
                  />
                </div>
                <div className={styles.userDetails}>
                  <div className={styles.userName}>
                    {card.name}
                    {card.verified && (
                      <svg
                        className={styles.verifiedBadge}
                        viewBox="0 0 24 24"
                        fill="currentColor"
                      >
                        <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                      </svg>
                    )}
                  </div>
                  <div className={styles.userLocation}>
                    {card.location}
                    {card.weeksUsing && (
                      <span className={styles.weeksUsing}>
                        {" "}
                        • {card.weeksUsing} sessions/day
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className={styles.comment}>
              <span className={styles.quoteMark}>"</span>
              {card.comment}
              <span className={styles.quoteMark}>"</span>
            </div>
          </div>
        ))}
        </div>
      </div>
    </div>
  );
};

export default LoveCards;
