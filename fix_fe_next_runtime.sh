#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# ---- helpers ---------------------------------------------------------------
ROOT="${PWD}"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT/.backup/fix-$TS"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

backup_path() {
  local p="$1"
  if [[ -e "$p" ]]; then
    local rel="${p#$ROOT/}"
    local dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$p" "$dest"
  fi
}

ensure_tree() {
  log "Ensuring directories"
  mkdir -p "$ROOT"/{app,components,public,styles/utils}
  mkdir -p "$BACKUP_DIR"
}

backup_pages_conflicts() {
  if [[ -d "$ROOT/pages" ]]; then
    local moved=false
    local pg="$ROOT/pages"
    local files=(index.tsx index.ts index.jsx index.js _app.tsx _app.ts _app.jsx _app.js _document.tsx _document.ts _document.jsx _document.js)
    for f in "${files[@]}"; do
      if [[ -f "$pg/$f" ]]; then
        mkdir -p "$BACKUP_DIR/pages"
        mv "$pg/$f" "$BACKUP_DIR/pages/"
        moved=true
      fi
    done
    if [[ "$moved" == true ]]; then
      log "Backed up conflicting Pages Router files to ${BACKUP_DIR#"$ROOT/"}"
    else
      log "No App/Pages conflicts found."
    fi
  fi
}

ensure_package_json() {
  if [[ -f "$ROOT/package.json" ]]; then
    log "package.json exists; ensuring scripts and deps with npm pkg set"
    if have npm; then
      ( cd "$ROOT"
        npm pkg set "scripts.dev=next dev"
        npm pkg set "scripts.build=next build"
        npm pkg set "scripts.start=next start -p 3000"
        npm pkg set "dependencies.next=14.2.32"
        npm pkg set "dependencies.react=18.3.1"
        npm pkg set "dependencies.react-dom=18.3.1"
        npm pkg set "dependencies.sass=^1.77.0"
        npm pkg set "devDependencies.typescript=^5.5.4"
        npm pkg set "devDependencies.@types/node=^20.11.30"
        npm pkg set "devDependencies.@types/react=^18.2.66"
      )
    else
      log "npm not found; leaving existing package.json as-is (deps must be present already)."
    fi
  else
    log "Writing package.json (new)"
    backup_path "$ROOT/package.json"
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
  fi
}

ensure_lockfile() {
  if [[ ! -f "$ROOT/package-lock.json" ]]; then
    if have npm; then
      log "Generating package-lock.json (npm install --package-lock-only)"
      ( cd "$ROOT" && npm install --package-lock-only >/dev/null 2>&1 || true )
    else
      log "npm not found; skipping lockfile generation (Docker will fall back to npm install)."
    fi
  else
    log "Found package-lock.json"
  fi
}

write_tsconfig() {
  log "Writing tsconfig.json & next-env.d.ts"
  backup_path "$ROOT/tsconfig.json"
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
    "baseUrl": "."
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
JSON

  backup_path "$ROOT/next-env.d.ts"
  cat > "$ROOT/next-env.d.ts" <<'TS'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
// NOTE: This file should not be edited
TS
}

write_next_config() {
  log "Writing next.config.mjs (standalone + SCSS includePaths)"
  backup_path "$ROOT/next.config.mjs"
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

write_app_scaffold() {
  log "Writing app/layout.tsx and app/page.tsx"
  backup_path "$ROOT/app/layout.tsx"
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

  backup_path "$ROOT/app/page.tsx"
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

write_component_and_styles() {
  log "Writing components/ParallaxHero.tsx"
  backup_path "$ROOT/components/ParallaxHero.tsx"
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

  log 'Writing components/ParallaxHero.module.scss (namespaced @use)'
  backup_path "$ROOT/components/ParallaxHero.module.scss"
  cat > "$ROOT/components/ParallaxHero.module.scss" <<'SCSS'
@use 'utils/variables' as v;
@use 'utils/mixins' as m;

.hero {
  position: relative;
  padding: 18vh 0;
  background:
    radial-gradient(1000px 400px at 10% 10%, rgba(255,255,255,.06), transparent 60%),
    radial-gradient(800px 400px at 90% 20%, rgba(255,255,255,.04), transparent 60%),
    linear-gradient(45deg, v.$brand, lighten(v.$brand, 14%));
  overflow: hidden;
  box-shadow: v.$shadow;
}

.inner { @include m.container; text-align: center; }

.title { font-size: clamp(2.2rem, 4vw + 1rem, 4.2rem); line-height: 1.1; margin: 0 0 1rem; }
.subtitle { font-size: clamp(1rem, 1vw + .8rem, 1.25rem); opacity: .9; margin: 0 0 1.75rem; }
.ctas { display:flex; gap:.75rem; justify-content:center; flex-wrap:wrap; }

.btnPrimary { @include m.button(v.$brand, #fff); }
.btnGhost { @include m.button(transparent, v.$text); outline: 1px solid rgba(255,255,255,.25); }
SCSS

  log 'Writing styles/utils/_variables.scss (defines $brand)'
  backup_path "$ROOT/styles/utils/_variables.scss"
  cat > "$ROOT/styles/utils/_variables.scss" <<'SCSS'
$brand:  #6c5ce7 !default; // vibrant indigo
$bg:     #0b0f14 !default;
$text:   #e6e9ef !default;
$muted:  #9aa4b2 !default;
$radius: 12px    !default;
$shadow: 0 10px 30px rgba(0,0,0,.35) !default;
SCSS

  log 'Writing styles/utils/_mixins.scss (imports variables and uses v.$brand)'
  backup_path "$ROOT/styles/utils/_mixins.scss"
  cat > "$ROOT/styles/utils/_mixins.scss" <<'SCSS'
@use './variables' as v;

@mixin button($bg: v.$brand, $fg: #fff) {
  background: $bg;
  color: $fg;
  border: 0;
  border-radius: v.$radius;
  padding: .65rem 1.05rem;
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
  transition: filter .15s ease;
  &:hover { filter: brightness(1.05); }
  &:active { filter: brightness(.95); }
}

@mixin container() {
  width: min(1100px, 100% - 2rem);
  margin-inline: auto;
}
SCSS

  log "Writing styles/globals.scss (imports variables before mixins)"
  backup_path "$ROOT/styles/globals.scss"
  cat > "$ROOT/styles/globals.scss" <<'SCSS'
@use 'utils/variables' as v;
@use 'utils/mixins' as m;

* { box-sizing: border-box; }
html, body { height: 100%; }
body {
  margin: 0;
  font-family:
    ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Noto Sans, Ubuntu,
    Cantarell, "Helvetica Neue", Arial, "Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol";
  background: v.$bg;
  color: v.$text;
}
a { color: inherit; text-decoration: none; }
SCSS
}

write_public_asset() {
  log "Adding placeholder hero.svg"
  if [[ ! -f "$ROOT/public/hero.svg" ]]; then
    cat > "$ROOT/public/hero.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#6c5ce7"/><stop offset="100%" stop-color="#8ea2ff"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>
SVG
  fi
}

write_dockerfile() {
  log "Writing Dockerfile (multi-stage, Next standalone)"
  backup_path "$ROOT/Dockerfile"
  cat > "$ROOT/Dockerfile" <<'DOCKER'
# syntax=docker/dockerfile:1.6
# ---- deps ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Deterministic if lockfile exists; fallback for first-time runs
RUN --mount=type=cache,target=/root/.npm npm ci || npm install

# ---- builder ----
FROM deps AS builder
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.npm npm run build

# ---- runtime ----
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
# Next standalone output contains server.js and minimal node_modules
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
DOCKER

  # .dockerignore
  backup_path "$ROOT/.dockerignore"
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
  ensure_package_json
  ensure_lockfile
  write_tsconfig
  write_next_config
  write_app_scaffold
  write_component_and_styles
  write_public_asset
  write_dockerfile

  log "Done. Build & run the frontend:"
  cat <<'MSG'
  docker compose build frontend && docker compose up -d frontend

Notes:
- If you kept legacy routes under pages/api/** they still work.
- All heredocs are quoted and echoes that mention $brand are single-quoted. No more "brand: unbound variable".
- Mixins import variables via @use and reference v.$brand, v.$radius, etc. No Sass scoping errors.
- For strict reproducibility, commit the generated package-lock.json.
MSG
}

main "$@"
