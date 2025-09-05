import ParallaxHero from '../components/ParallaxHero';

export default function Page() {
  return (
    <main>
      <ParallaxHero />
      <section style={{ maxWidth: 960, margin: '2rem auto', padding: '0 1rem' }}>
        <h2>Welcome to Wallet-Recovery</h2>
        <p>
          Secure, authenticated, watch-only recovery workflows with multi-chain scanning.
          Login via PGP (admin-provisioned keys) will appear here in Step 2/3.
        </p>
      </section>
    </main>
  );
}
