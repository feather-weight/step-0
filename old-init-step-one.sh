#!/usr/bin/env bash
set -euo pipefail

echo "=== Step 1 (wallet-recovery): Next.js + PGP-ready backend + Docker bootstrap ==="

# ---- sanity checks ----
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1. Please install and re-run."; exit 1; }; }
need node
need npm
need python3
need openssl

echo "Node: $(node -v) | npm: $(npm -v) | Python: $(python3 -V)"

# ---- base layout ----
mkdir -p frontend backend/app/{api,core,db,models,services} deploy certs
touch backend/app/__init__.py

# ---- .env (create once) ----
if [ ! -f .env ]; then
  cat > .env <<'EOF'
# === Core ===
PROJECT_NAME=multi-chain-wallet-recovery
API_BASE=/api
MONGO_URI=mongodb://mongo:27017/wallet_recovery_db
MONGO_DB=wallet_recovery_db

# === Security ===
JWT_SECRET=
JWT_EXPIRES_SECONDS=3600

# === Providers ===
BLOCKCHAIR_API_KEY=
INFURA_PROJECT_ID=
INFURA_PROJECT_SECRET=
TATUM_API_KEY=

# === Policy ===
MAINNET_ONLY=true
DISABLE_TESTNET=true

# === PGP Auth Switch ===
PGP_ENABLE=true
GPG_HOME=/app/.gnupg
GPG_KEYSERVER=hkps://keys.openpgp.org

# === Frontend ===
NEXT_PUBLIC_API_BASE=
EOF
  # one-time secret
  if command -v openssl >/dev/null 2>&1; then
    sed -i '' -e "s#^JWT_SECRET=.*#JWT_SECRET=$(openssl rand -hex 64)#" .env 2>/dev/null || \
    sed -i -e "s#^JWT_SECRET=.*#JWT_SECRET=$(openssl rand -hex 64)#" .env
  fi
fi

# ---- BACKEND: Dockerfile + requirements + minimal app ----
if [ ! -f backend/Dockerfile ]; then
  cat > backend/Dockerfile <<'EOF'
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# PGP tools for later steps; harmless at Step 1
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app /app/app

# PGP home with strict perms (used in Step 2+)
RUN mkdir -p /app/.gnupg && chmod 700 /app/.gnupg

EXPOSE 8000
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]
EOF
fi

cat > backend/requirements.txt <<'EOF'
fastapi==0.111.0
uvicorn==0.30.3
motor==3.5.1
pydantic==2.8.2
python-jose==3.3.0    # used only for short-lived session cookie in Step 2+
pgpy==0.6.0           # PGP ops in Step 2+
python-dotenv==1.0.1
httpx==0.27.0
tenacity==8.5.0
loguru==0.7.2
EOF

cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api import routes_health

app = FastAPI(title=settings.PROJECT_NAME)

# CORS (relaxed for dev; tighten in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    # Initialize Mongo driver (no collections required at Step 1)
    from app.db.client import init_mongo
    await init_mongo()

# Health
app.include_router(routes_health.router, prefix="/health", tags=["health"])
EOF

cat > backend/app/api/routes_health.py <<'EOF'
from fastapi import APIRouter
router = APIRouter()

@router.get("")
async def health():
    return {"status":"ok"}
EOF

cat > backend/app/core/config.py <<'EOF'
import os
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = os.getenv("PROJECT_NAME","multi-chain-wallet-recovery")
    API_BASE: str = os.getenv("API_BASE","/api")
    MONGO_URI: str = os.getenv("MONGO_URI","mongodb://mongo:27017/wallet_recovery_db")
    MONGO_DB: str = os.getenv("MONGO_DB","wallet_recovery_db")
    JWT_SECRET: str = os.getenv("JWT_SECRET","changeme")
    JWT_EXPIRES_SECONDS: int = int(os.getenv("JWT_EXPIRES_SECONDS","3600"))
    PGP_ENABLE: bool = os.getenv("PGP_ENABLE","true").lower() == "true"
    GPG_HOME: str = os.getenv("GPG_HOME","/app/.gnupg")
    GPG_KEYSERVER: str = os.getenv("GPG_KEYSERVER","hkps://keys.openpgp.org")

settings = Settings()
EOF

cat > backend/app/db/client.py <<'EOF'
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

mongo = None
db = None

async def init_mongo():
    global mongo, db
    mongo = AsyncIOMotorClient(settings.MONGO_URI)
    db = mongo[settings.MONGO_DB]
    # Step 1: no indexes yet; Step 2 will add users/public_key/active indexes
EOF

# ---- FRONTEND: Next.js bootstrap (create lockfile once; no classic login) ----
if [ ! -f frontend/package.json ]; then
  echo "== Bootstrapping Next.js (generates package-lock.json)…"
  # Create a minimal Next.js app (manual—no prompts; ensures lockfile)
  cat > frontend/package.json <<'EOF'
{
  "name": "wallet-recovery-frontend",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "axios": "1.7.3"
  },
  "devDependencies": {
    "typescript": "5.5.4",
    "@types/node": "20.14.10",
    "@types/react": "18.3.3",
    "tailwindcss": "3.4.10",
    "postcss": "8.4.41",
    "autoprefixer": "10.4.19",
    "eslint": "9.8.0",
    "eslint-config-next": "14.2.5",
    "eslint-config-prettier": "9.1.0",
    "prettier": "3.3.3"
  }
}
EOF

  (cd frontend && npm install)

  # next / ts / tailwind basics
  cat > frontend/next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true, output: 'standalone' };
export default nextConfig;
EOF

  cat > frontend/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "es2022"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "forceConsistentCasingInFileNames": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF

  cat > frontend/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./pages/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};
EOF

  cat > frontend/postcss.config.js <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

  mkdir -p frontend/pages frontend/components frontend/lib frontend/styles
  cat > frontend/styles/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body, #__next { height: 100%; }
body { @apply bg-neutral-950 text-neutral-100; }
button { @apply bg-indigo-600 hover:bg-indigo-500 text-white px-4 py-2 rounded; }
input, textarea { @apply w-full bg-neutral-900 text-neutral-100 rounded px-3 py-2 outline-none border border-neutral-800;}
label { @apply text-sm opacity-80; }
EOF

  # minimal API client (baseURL uses NEXT_PUBLIC_API_BASE; empty = same-origin through Nginx)
  cat > frontend/lib/api.ts <<'EOF'
import axios from "axios";
const api = axios.create({
  withCredentials: true,
  baseURL: process.env.NEXT_PUBLIC_API_BASE || ""
});
export default api;
EOF

  # _app
  cat > frontend/pages/_app.tsx <<'EOF'
import type { AppProps } from "next/app";
import "../styles/globals.css";
export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
EOF

  # Home -> redirect to /login
  cat > frontend/pages/index.tsx <<'EOF'
import { useEffect } from "react";
export default function Home(){
  useEffect(()=>{ window.location.href="/login"; },[]);
  return null;
}
EOF

  # PGP Login Modal placeholder (no API calls yet in Step 1)
  cat > frontend/components/PGPLoginModal.tsx <<'EOF'
import { useState } from "react";

export default function PGPLoginModal({onClose}:{onClose:()=>void}) {
  const [pub,setPub]=useState("");
  const [challenge,setChallenge]=useState<string|null>(null);
  const [tokenResp,setTokenResp]=useState("");

  return (
    <div className="fixed inset-0 bg-black/60 grid place-items-center p-4">
      <div className="w-full max-w-2xl bg-neutral-900 rounded-2xl p-6 space-y-4 border border-neutral-800">
        <h2 className="text-xl font-semibold">PGP Login (Step 2+ wires this)</h2>
        {!challenge && (
          <>
            <label>Your PGP <b>public</b> key (ASCII-armored)</label>
            <textarea rows={8} value={pub} onChange={e=>setPub(e.target.value)} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" />
            <div className="flex gap-3">
              <button onClick={()=>setChallenge('Encrypted challenge will appear here in Step 2')}>Get Challenge</button>
              <button className="bg-neutral-700 hover:bg-neutral-600" onClick={onClose}>Cancel</button>
            </div>
          </>
        )}
        {challenge && (
          <>
            <p className="opacity-80">Decrypt this message with your private key, then paste the plaintext token.</p>
            <pre className="bg-neutral-800 p-3 rounded">{challenge}</pre>
            <input value={tokenResp} onChange={e=>setTokenResp(e.target.value)} placeholder="Decrypted token" />
            <div className="flex gap-3">
              <button onClick={()=>alert('Verification will be implemented in Step 2/3')}>Verify</button>
              <button className="bg-neutral-700 hover:bg-neutral-600" onClick={onClose}>Close</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
EOF

  # Login page that uses the PGP modal (placeholder)
  cat > frontend/pages/login.tsx <<'EOF'
import { useState } from "react";
import dynamic from "next/dynamic";

const PGPLoginModal = dynamic(()=>import("../components/PGPLoginModal"), { ssr:false });

export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <main className="min-h-screen grid place-items-center p-6">
      <div className="w-full max-w-xl bg-neutral-900 rounded-2xl p-8 border border-neutral-800 space-y-4">
        <h1 className="text-2xl font-semibold">Sign In with PGP</h1>
        <p className="opacity-75">
          This app uses admin-approved PGP public keys. Classic email/password is not supported.
        </p>
        <button onClick={()=>setOpen(true)}>Begin PGP Login</button>
      </div>
      {open && <PGPLoginModal onClose={()=>setOpen(false)} />}
    </main>
  );
}
EOF

else
  # Already initialized: deterministic install
  if [ -f frontend/package-lock.json ]; then
    (cd frontend && npm ci)
  else
    (cd frontend && npm install)
  fi
fi

# ---- FRONTEND Dockerfile ----
if [ ! -f frontend/Dockerfile ]; then
  cat > frontend/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci || npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm","run","start"]
EOF
fi

# ---- docker-compose ----
if [ ! -f docker-compose.yml ]; then
  cat > docker-compose.yml <<'EOF'
version: "3.9"
services:
  mongo:
    image: mongo:6
    restart: unless-stopped
    volumes: [ "mongo_data:/data/db" ]
    ports: [ "27017:27017" ]

  backend:
    build: ./backend
    env_file: .env
    volumes:
      - ./backend/app:/app/app
      - backend_gnupg:/app/.gnupg
    depends_on: [ mongo ]
    ports: [ "8000:8000" ]
    restart: unless-stopped

  frontend:
    build: ./frontend
    env_file: .env
    environment:
      - NEXT_PUBLIC_API_BASE=
    volumes:
      - ./frontend:/app
    depends_on: [ backend ]
    ports: [ "3000:3000" ]
    restart: unless-stopped

  nginx:
    image: nginx:1.27-alpine
    depends_on: [ frontend, backend ]
    volumes:
      - ./deploy/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "80:80"
    restart: unless-stopped

volumes:
  mongo_data:
  backend_gnupg:
EOF
fi

# ---- nginx proxy ----
mkdir -p deploy
if [ ! -f deploy/nginx.conf ]; then
  cat > deploy/nginx.conf <<'EOF'
server {
  listen 80;
  server_name _;

  client_max_body_size 10m;

  location /api/ {
    proxy_pass http://backend:8000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location / {
    proxy_pass http://frontend:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
EOF
fi

cat <<'DONE'

✅ Step 1 complete for wallet-recovery.

What you have now:
- Next.js app with a **PGP Login spot** (Login page + PGP modal placeholder; no classic login).
- FastAPI backend (healthcheck only in Step 1), PGP-ready deps & GPG home.
- Docker Compose for frontend, backend, Mongo, Nginx.
- `.env` populated (recovery-only posture, PGP_ENABLE=true).

Run:
  docker compose up --build
Open:
  Frontend: http://localhost:3000  (Login shows PGP modal placeholder)
  Backend:  http://localhost:8000/health

Next:
  Step 2 wires backend PGP endpoints (/api/auth/register, /auth/login/start, /auth/login/verify)
  Step 3 connects the frontend modal to those APIs and adds route protection.
DONE

