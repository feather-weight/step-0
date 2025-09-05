#!/usr/bin/env bash
set -Eeuo pipefail

on_err() {
  echo "❌ Error on line $LINENO. Aborting." >&2
}
trap on_err ERR

log() { printf '\n==> %s\n' "$*"; }

# --- Paths ---
ROOT="${PWD}"

# --- Helpers ---
backup_pages_conflicts() {
  if [[ -d "$ROOT/pages" ]]; then
    local ts backup moved=false
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="$ROOT/.backup/pages-$ts"
    mkdir -p "$backup"

    # Conflicting files when using App Router
    local files=(index.tsx index.jsx index.ts index.js _app.tsx _app.jsx _document.tsx _document.jsx)
    for f in "${files[@]}"; do
      if [[ -f "$ROOT/pages/$f" ]]; then
        mkdir -p "$backup"
        mv "$ROOT/pages/$f" "$backup/"
        moved=true
      fi
    done

    if [[ "$moved" == true ]]; then
      log "Detected Pages Router conflicts. Backed up to .backup/pages-$ts"
      # If pages dir is now empty except api, keep it.
      # Nothing else to do.
    else
      log "No conflicting files in /pages; leaving it as-is (api routes are fine)."
    fi
  fi
}

ensure_tree() {
  log "Ensuring frontend directory exists"
  mkdir -p "$ROOT"/{app,components,public,styles/utils}
}

write_package_json() {
  log "Writing package.json (wallet-recovery)"
  cat > "$ROOT/package.json" <<'JSON'
{
  "name": "wallet-recovery",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "14.2.32",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "sass": "^1.77.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.30",
    "@types/react": "^18.2.66",
    "typescript": "^5.5.4"
  }
}
JSON
}

write_tsconfig() {
  log "Writing tsconfig.json"
  cat > "$ROOT/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "baseUrl": ".",
    "paths": {}
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
JSON

  # Standard Next TS shim
  cat > "$ROOT/next-env.d.ts" <<'TS'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
// NOTE: This file should not be edited
TS
}

write_next_config() {
  log "Writing next.config.mjs (standalone output + SCSS includePaths)"
  cat > "$ROOT/next.config.mjs" <<'JS'
import path from 'path';

const nextConfig = {
  output: 'standalone',
  experimental: { typedRoutes: true },
  sassOptions: {
    includePaths: [
      path.join(process.cwd(), 'styles'),
      path.join(process.cwd(), 'styles', 'utils')
    ]
  }
};

export default nextConfig;
JS
}

write_app() {
  log "Creating app structure"
  mkdir -p "$ROOT/app"

  log "Writing app/layout.tsx"
  cat > "$ROOT/app/layout.tsx" <<'TSX'
import '../styles/globals.scss';

export const metadata = {
  title: 'Sick Scents',
  description: 'Next App Router + SCSS baseline',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
TSX

  log "Writing app/page.tsx (uses ParallaxHero)"
  cat > "$ROOT/app/page.tsx" <<'TSX'
import ParallaxHero from '../components/ParallaxHero';

export default function Page() {
  return (
    <main>
      <ParallaxHero />
    </main>
  );
}
TSX
}

write_component() {
  log "Writing components/ParallaxHero.tsx and SCSS module"
  cat > "$ROOT/components/ParallaxHero.tsx" <<'TSX'
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
TSX

  cat > "$ROOT/components/ParallaxHero.module.scss" <<'SCSS'
@use 'utils/variables' as *;
@use 'utils/mixins' as *;

.hero {
  position: relative;
  padding: 18vh 0;
  background:
    radial-gradient(1000px 400px at 10% 10%, rgba(255,255,255,.06), transparent 60%),
    radial-gradient(800px 400px at 90% 20%, rgba(255,255,255,.04), transparent 60%),
    linear-gradient(45deg, $brand, lighten($brand, 14%));
  overflow: hidden;
  box-shadow: $shadow;
}

.inner { @include container; text-align: center; }

.title { font-size: clamp(2.2rem, 4vw + 1rem, 4.2rem); line-height: 1.1; margin: 0 0 1rem; }
.subtitle { font-size: clamp(1rem, 1vw + .8rem, 1.25rem); opacity: .9; margin: 0 0 1.75rem; }
.ctas { display:flex; gap:.75rem; justify-content:center; flex-wrap:wrap; }

.btnPrimary { @include button($brand, #fff); }
.btnGhost { @include button(transparent, $text); outline: 1px solid rgba(255,255,255,.25); }
SCSS
}

write_styles() {
  log 'Writing styles/utils/_variables.scss (defines $brand)'
  cat > "$ROOT/styles/utils/_variables.scss" <<'SCSS'
$brand:  #6c5ce7 !default; // vibrant indigo
$bg:     #0b0f14 !default;
$text:   #e6e9ef !default;
$muted:  #9aa4b2 !default;
$radius: 12px    !default;
$shadow: 0 10px 30px rgba(0,0,0,.35) !default;
SCSS

  log 'Writing styles/utils/_mixins.scss (uses $brand)'
  cat > "$ROOT/styles/utils/_mixins.scss" <<'SCSS'
@mixin button($bg:$brand, $fg:#fff) {
  background: $bg;
  color: $fg;
  border: 0;
  border-radius: $radius;
  padding: .65rem 1.05rem;
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
  transition: filter .15s ease;
  &:hover { filter: brightness(1.05); }
  &:active { filter: brightness(.95); }
}

@mixin container {
  width: min(1100px, 100% - 2rem);
  margin-inline: auto;
}
SCSS

  log "Writing styles/globals.scss (imports variables before mixins)"
  cat > "$ROOT/styles/globals.scss" <<'SCSS'
@use 'utils/variables' as *;
@use 'utils/mixins' as *;

* { box-sizing: border-box; }
html, body { height: 100%; }
body {
  margin: 0;
  font-family:
    ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Noto Sans, Ubuntu,
    Cantarell, "Helvetica Neue", Arial, "Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol";
  background: $bg;
  color: $text;
}
a { color: inherit; text-decoration: none; }
SCSS
}

write_public_assets() {
  log "Adding a tiny placeholder hero SVG if missing"
  if [[ ! -f "$ROOT/public/hero.svg" ]]; then
    cat > "$ROOT/public/hero.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#6c5ce7"/>
      <stop offset="100%" stop-color="#8ea2ff"/>
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>
SVG
  fi
}

write_dockerfile() {
  log "Writing frontend Dockerfile (multi-stage, standalone runtime)"
  cat > "$ROOT/Dockerfile" <<'DOCKER'
# syntax=docker/dockerfile:1.6
# ---- deps ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Use npm ci when lockfile exists, fallback to install otherwise
RUN --mount=type=cache,target=/root/.npm npm ci || npm install

# ---- builder ----
FROM deps AS builder
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.npm npm run build

# ---- runtime (no next CLI required) ----
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
# Copy Next standalone output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
DOCKER
}

write_dockerignore() {
  cat > "$ROOT/.dockerignore" <<'IGN'
node_modules
.next
.git
*.log
.DS_Store
.backup
IGN
}

main() {
  ensure_tree
  backup_pages_conflicts
  write_package_json
  write_tsconfig
  write_next_config
  write_app
  write_component
  write_styles
  write_public_assets
  write_dockerfile
  write_dockerignore

  log "Done. Rebuild the frontend image and start the stack:"
  cat <<'MSG'
    docker compose build frontend && docker compose up -d frontend
    If you use nginx in compose, open: http://localhost (else http://localhost:3000)

Tip: If you want reproducible installs with `npm ci`, generate a lockfile once:
    npm install --package-lock-only
MSG
}

main "$@"
