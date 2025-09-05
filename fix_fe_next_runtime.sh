#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FRONTEND_DIR="${ROOT}/frontend"

echo "==> Ensuring frontend directory exists"
mkdir -p "${FRONTEND_DIR}"
cd "${FRONTEND_DIR}"

echo "==> Writing package.json (wallet-recovery)"
cat > package.json <<'JSON'
{
  "name": "wallet-recovery-frontend",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "node .next/standalone/server.js"
  },
  "dependencies": {
    "next": "14.2.32",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "axios": "1.11.0",
    "sass": "^1.80.3"
  }
}
JSON

echo "==> Writing tsconfig.json"
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "es2022"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "esModuleInterop": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
JSON

echo "==> Writing next.config.mjs (standalone output + SCSS includePaths)"
cat > next.config.mjs <<'JS'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  experimental: { typedRoutes: true },
  sassOptions: {
    includePaths: ['styles', 'styles/utils']
  }
};
export default nextConfig;
JS

echo "==> Creating app structure"
mkdir -p app styles/utils components public

echo "==> Writing app/layout.tsx"
cat > app/layout.tsx <<'TSX'
import '../styles/globals.scss';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Wallet-Recovery',
  description: 'Multi-chain wallet recovery (watch-only) dashboard'
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
TSX

echo "==> Writing app/page.tsx (uses ParallaxHero)"
cat > app/page.tsx <<'TSX'
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
TSX

echo "==> Writing components/ParallaxHero.tsx and SCSS module"
cat > components/ParallaxHero.tsx <<'TSX'
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
TSX

cat > components/ParallaxHero.module.scss <<'SCSS'
@use '../styles/utils/variables' as *;
@use '../styles/utils/mixins' as *;

.hero {
  background-image:     -gradient(180deg, rgba(0,0,0,0.35), rgba(0,0,0,0.65)), url('/hero-bg.jpg');
  background-size: cover;
  background-repeat: no-repeat;
  background-attachment: scroll; // we update position via JS
  background-position: center 0;
  color: #fff;
  min-height: 52vh;
  display: grid;
  place-items: center;
}

.inner {
  text-align: center;
  padding: 3rem 1rem;
  max-width: 960px;
}

h1 { font-weight: 800; font-size: clamp(2rem, 4vw, 3rem); margin: 0 0 .5rem; }
p  { margin: 0 0 1.25rem; opacity: .95; }

.cta {
  @include button($brand, #fff);
  text-decoration: none;
  font-weight: 600;
}
SCSS

echo '==> Writing styles/utils/_variables.scss (defines $brand)'
cat > styles/utils/_variables.scss <<'SCSS'
$brand: #6c5ce7 !default;          // vibrant indigo
$bg:    #0b0f14 !default;
$text:  #e6e9ef !default;
SCSS

echo '==> Writing styles/utils/_mixins.scss (uses $brand)'
cat > styles/utils/_mixins.scss <<'SCSS'
@mixin button($bg:$brand, $fg:#fff) {
  background: $bg;
  color: $fg;
  border: 0;
  border-radius: 10px;
  padding: .65rem 1.05rem;
  cursor: pointer;
  transition: transform .12s ease, filter .12s ease;
  display: inline-block;
  &:hover { transform: translateY(-1px); filter: brightness(1.05); }
  &:active { transform: translateY(0); filter: brightness(.98); }
}
SCSS

echo "==> Writing styles/globals.scss (imports variables before mixins)"
cat > styles/globals.scss <<'SCSS'
@use 'utils/variables' as *;
@use 'utils/mixins' as *;

:root {
  color-scheme: dark;
}

* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: $bg; color: $text; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, 'Helvetica Neue', Arial, 'Apple Color Emoji', 'Segoe UI Emoji'; }

a { color: inherit; }
SCSS

echo "==> Adding a placeholder hero image if missing"
if [ ! -f public/hero-bg.jpg ]; then
  # minimal single-pixel file placeholder to avoid 404; replace in design
  printf '\377\330\377\340JFIF\000\001\001\000\000\001\000\001\000\000\377\331' > public/hero-bg.jpg
fi

echo "==> Writing frontend Dockerfile (multi-stage, standalone runtime)"
cat > Dockerfile <<'DOCKER'
# ---- dependencies / build ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
# If you have a lock file, copy it as well to prefer deterministic installs:
# COPY package-lock.json ./
RUN npm ci || npm install

FROM deps AS builder
COPY . .
RUN npm run build

# ---- runtime (no next CLI required) ----
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# Copy "standalone" server output
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./.next/standalone
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["node", ".next/standalone/server.js"]
DOCKER

echo "==> Done. Rebuild the frontend image and start the stack:"
echo "    docker compose build frontend && docker compose up -d frontend"
echo "    If you use nginx in compose, open: http://localhost (else http://localhost:3000)"

