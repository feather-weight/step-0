'use client';

import styles from './ParallaxHero.module.scss';
import { useEffect, useRef } from 'react';

export default function ParallaxHero() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY || 0;
      if (ref.current) {
        // Simple parallax: move background slower than scroll
        ref.current.style.backgroundPositionY = `${Math.round(y * 0.4)}px`;
      }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header ref={ref} className={styles.hero}>
      <div className={styles.inner}>
        <h1>Wallet‑Recovery</h1>
        <p>Fast, ethical, watch‑only recovery scanning across chains.</p>
        <a className={styles.cta} href="/dashboard">Open Dashboard</a>
      </div>
    </header>
  );
}
