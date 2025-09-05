'use client';
import styles from './ParallaxHero.module.scss';

export default function ParallaxHero() {
  return (
    <section className={styles.hero} role="banner">
      <div className={styles.inner}>
        <h1 className={styles.title}>Sick Scents</h1>
        <p className={styles.subtitle}>
          Modern Next.js App Router + SCSS. Brand color is wired into the gradient.
        </p>
        <div className={styles.ctas}>
          <a className={styles.btnPrimary} href="/shop">Shop now</a>
          <a className={styles.btnGhost} href="/about">Learn more</a>
        </div>
      </div>
    </section>
  );
}
