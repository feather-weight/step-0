#!/usr/bin/env bash
set -euo pipefail

echo "=== Step 1 (wallet-recovery): Next.js + PGP-ready backend + Docker bootstrap ==="

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1. Install it and re-run."; exit 1; }; }
need node; need npm; need python3; need openssl
echo "Node: $(node -v) | npm: $(npm -v) | Python: $(python3 -V)"

# --- base layout (create BEFORE writing files) ---
mkdir -p frontend
mkdir -p backend/app/{api,core,db,models,services}
mkdir -p deploy certs
touch backend/app/__init__.py

# --- .env ---
if [ ! -f .env ]; then
  cat > .env <<'EOF'
PROJECT_NAME=multi-chain-wallet-recovery
API_BASE=/api
MONGO_URI=mongodb://mongo:27017/wallet_recovery_db
MONGO_DB=wallet_recovery_db
JWT_SECRET=
JWT_EXPIRES_SECONDS=3600
BLOCKCHAIR_API_KEY=
INFURA_PROJECT_ID=
INFURA_PROJECT_SECRET=
TATUM_API_KEY=
MAINNET_ONLY=true
DISABLE_TESTNET=true
PGP_ENABLE=true
GPG_HOME=/app/.gnupg
GPG_KEYSERVER=hkps://keys.openpgp.org
NEXT_PUBLIC_API_BASE=
EOF
  # fill JWT secret once (macOS + GNU sed compatible)
  if command -v openssl >/dev/null 2>&1; then
    SECRET=$(openssl rand -hex 64)
    (sed -i '' -e "s#^JWT_SECRET=.*#JWT_SECRET=${SECRET}#" .env 2>/dev/null) || \
    (sed -i -e "s#^JWT_SECRET=.*#JWT_SECRET=${SECRET}#" .env)
  fi
fi

# --- backend Dockerfile ---
if [ ! -f backend/Dockerfile ]; then
  cat > backend/Dockerfile <<'EOF'
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gnupg ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY app /app/app
RUN mkdir -p /app/.gnupg && chmod 700 /app/.gnupg
EXPOSE 8000
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]
EOF
fi

# --- backend requirements (includes PGPy for Step 2) ---
cat > backend/requirements.txt <<'EOF'
fastapi==0.111.0
uvicorn==0.30.3
motor==3.5.1
pydantic==2.8.2
python-jose==3.3.0
pgpy==0.6.0
python-dotenv==1.0.1
httpx==0.27.0
tenacity==8.5.0
loguru==0.7.2
EOF

# --- backend minimal app (write using full paths, no cd) ---
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
    # Indexes come in Step 2
EOF

cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import routes_health

app = FastAPI(title="multi-chain-wallet-recovery")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

@app.get("/health")
async def health():
    return {"status": "ok"}
EOF

# --- frontend Next.js bootstrap (creates package-lock on first run) ---
if [ ! -f frontend/package.json ]; then
  cat > frontend/package.json <<'EOF'
{
  "name": "wallet-recovery-frontend",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
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
    "autoprefixer": "10.4.19"
  }
}
EOF
  (cd frontend && npm install)
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
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve"
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF
  cat > frontend/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = { content: ["./pages/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"], theme: { extend: {} }, plugins: [] };
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
body { background: #0a0a0a; color: #f5f5f5; }
button { background:#4f46e5; color:white; padding:.5rem 1rem; border-radius:.5rem; }
input, textarea { width:100%; background:#111; color:#f5f5f5; border:1px solid #222; border-radius:.5rem; padding:.5rem .75rem; }
EOF
  cat > frontend/pages/_app.tsx <<'EOF'
import type { AppProps } from "next/app";
import "../styles/globals.css";
export default function App({ Component, pageProps }: AppProps) { return <Component {...pageProps} />; }
EOF
  cat > frontend/pages/index.tsx <<'EOF'
import { useEffect } from "react";
export default function Home(){ useEffect(()=>{ window.location.href="/login"; },[]); return null; }
EOF
  # PGP login placeholder (the actual wiring happens in Step 3)
  cat > frontend/pages/login.tsx <<'EOF'
import { useState } from "react";
export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <main className="min-h-screen grid place-items-center p-6">
      <div className="w-full max-w-xl bg-neutral-900 rounded-2xl p-8 border border-neutral-800 space-y-4">
        <h1 className="text-2xl font-semibold">Sign In with PGP</h1>
        <p className="opacity-75">Admin-approved PGP keys only. Classic login is disabled.</p>
        <button onClick={()=>setOpen(true)}>Begin PGP Login</button>
        {open && <div className="mt-4 text-sm opacity-75">Modal placeholder. Step 3 will wire API calls.</div>}
      </div>
    </main>
  );
}
EOF
else
  if [ -f frontend/package-lock.json ]; then (cd frontend && npm ci); else (cd frontend && npm install); fi
fi

# --- frontend Dockerfile ---
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

# --- docker-compose ---
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
    environment: [ "NEXT_PUBLIC_API_BASE=" ]
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

# --- nginx config ---
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

echo "✅ Step 1 complete. Run: docker compose up --build"
echo "Frontend: http://localhost:3000  |  Backend health: http://localhost:8000/health"

