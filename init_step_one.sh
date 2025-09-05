#!/usr/bin/env bash
set -euo pipefail

echo "=== Step 1: wallet-recovery bootstrap (Next.js + SCSS + Parallax + FastAPI + Compose) ==="

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1. Install and re-run."; exit 1; }; }
need node; need npm; need python3; need openssl

# --- Layout -------------------------------------------------------------------
mkdir -p backend/app/{api,core,db,models,services} frontend deploy certs
touch backend/app/__init__.py

# --- .env ---------------------------------------------------------------------
if [ ! -f .env ]; then
  cat > .env <<'EOF'
# Project
PROJECT_NAME=wallet-recovery
API_BASE=/api

# Mongo
MONGO_URI=mongodb://mongo:27017/wallet_recovery_db
MONGO_DB=wallet_recovery_db

# Session
JWT_SECRET=
JWT_EXPIRES_SECONDS=3600
SECURE_COOKIES=false

# Admin bootstrap (temporary way to approve users & grant credits)
ADMIN_BOOTSTRAP_TOKEN=

# Providers
BLOCKCHAIR_API_KEY=
INFURA_PROJECT_ID=
INFURA_PROJECT_SECRET=
TATUM_API_KEY=

# Policy
MAINNET_ONLY=true
DISABLE_TESTNET=true

# PGP
PGP_ENABLE=true
GPG_HOME=/app/.gnupg
GPG_KEYSERVER=hkps://keys.openpgp.org

# Frontend (blank => same-origin via nginx)
NEXT_PUBLIC_API_BASE=
EOF
  SECRET=$(openssl rand -hex 64)
  BOOT=$(openssl rand -hex 32)
  # macOS or GNU sed
  (sed -i '' -e "s#^JWT_SECRET=.*#JWT_SECRET=${SECRET}#" .env 2>/dev/null) || sed -i -e "s#^JWT_SECRET=.*#JWT_SECRET=${SECRET}#" .env
  (sed -i '' -e "s#^ADMIN_BOOTSTRAP_TOKEN=.*#ADMIN_BOOTSTRAP_TOKEN=${BOOT}#" .env 2>/dev/null) || sed -i -e "s#^ADMIN_BOOTSTRAP_TOKEN=.*#ADMIN_BOOTSTRAP_TOKEN=${BOOT}#" .env
fi

# --- Backend Dockerfile -------------------------------------------------------
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

# --- Backend requirements (pins are important) --------------------------------
cat > backend/requirements.txt <<'EOF'
fastapi==0.111.0
uvicorn==0.30.3
motor==3.7.1
pymongo==4.11.1
pydantic==2.8.2
python-jose==3.3.0
pgpy==0.6.0
cryptography==42.0.8
python-dotenv==1.0.1
httpx==0.27.0
tenacity==8.5.0
loguru==0.7.2
EOF

# --- Backend app skeleton -----------------------------------------------------
cat > backend/app/api/routes_health.py <<'EOF'
from fastapi import APIRouter
router = APIRouter()
@router.get("")
async def health(): return {"status":"ok"}
EOF

cat > backend/app/core/config.py <<'EOF'
import os
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = os.getenv("PROJECT_NAME","wallet-recovery")
    API_BASE: str = os.getenv("API_BASE","/api")
    MONGO_URI: str = os.getenv("MONGO_URI","mongodb://mongo:27017/wallet_recovery_db")
    MONGO_DB: str = os.getenv("MONGO_DB","wallet_recovery_db")
    JWT_SECRET: str = os.getenv("JWT_SECRET","changeme")
    JWT_EXPIRES_SECONDS: int = int(os.getenv("JWT_EXPIRES_SECONDS","3600"))
    SECURE_COOKIES: bool = os.getenv("SECURE_COOKIES","false").lower()=="true"
    ADMIN_BOOTSTRAP_TOKEN: str = os.getenv("ADMIN_BOOTSTRAP_TOKEN","")
    PGP_ENABLE: bool = os.getenv("PGP_ENABLE","true").lower() == "true"
    GPG_HOME: str = os.getenv("GPG_HOME","/app/.gnupg")
    GPG_KEYSERVER: str = os.getenv("GPG_KEYSERVER","hkps://keys.openpgp.org")
    BLOCKCHAIR_API_KEY: str = os.getenv("BLOCKCHAIR_API_KEY","")

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
    # Step 2/3 will create indexes
EOF

cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import routes_health

app = FastAPI(title="wallet-recovery")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

@app.get("/health")
async def health(): return {"status":"ok"}
EOF

# --- Frontend: Next.js + SCSS + Parallax -------------------------------------
if [ ! -f frontend/package.json ]; then
  cat > frontend/package.json <<'EOF'
{
  "name": "wallet-recovery-frontend",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
  "dependencies": {
    "next": "14.2.32",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "axios": "1.11.0"
  },
  "devDependencies": {
    "typescript": "5.5.4",
    "@types/node": "20.14.10",
    "@types/react": "18.3.3",
    "sass": "^1.77.0"
  }
}
EOF
  (cd frontend && npm install)
fi

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

mkdir -p frontend/{pages,components,lib,styles,styles/utils,styles/components}

# SCSS
cat > frontend/styles/utils/_variables.scss <<'EOF'
$bg: #0a0a0a; $panel: #121212; $border: #222; $text: #f5f5f5; $brand: #4f46e5; $muted: #9ca3af; $radius: 12px;
EOF
cat > frontend/styles/utils/_mixins.scss <<'EOF'
@mixin card { background:$panel; border:1px solid $border; border-radius:$radius; padding:24px; box-shadow:0 10px 40px rgba(0,0,0,.35); }
@mixin button($bg:$brand,$fg:#fff){ background:$bg; color:$fg; border:0; border-radius:8px; padding:.6rem 1rem; cursor:pointer; }
EOF
cat > frontend/styles/components/_parallax.scss <<'EOF'
.parallax-root{ position:relative; height:50vh; min-height:340px; overflow:clip; background:linear-gradient(180deg,#121212 0%,#0a0a0a 100%); }
.parallax-layer{ position:absolute; inset:0; will-change:transform,opacity; }
.parallax-stars{ background-image:
  radial-gradient(2px 2px at 20% 30%, rgba(255,255,255,.45) 50%, transparent 51%),
  radial-gradient(1.5px 1.5px at 70% 60%, rgba(255,255,255,.35) 50%, transparent 51%),
  radial-gradient(1px 1px at 45% 80%, rgba(255,255,255,.25) 50%, transparent 51%);
  background-repeat:repeat; background-size:400px 300px,360px 320px,300px 280px; opacity:.5;
}
.parallax-gradient{ background: radial-gradient(1200px 500px at 50% 130%, rgba(79,70,229,.25), transparent 60%); mix-blend-mode: screen; }
.parallax-content{ position:relative; z-index:5; height:100%; display:grid; place-items:center; text-align:center; padding:1rem; }
EOF
cat > frontend/styles/globals.scss <<'EOF'
@use "utils/variables" as *; @use "utils/mixins" as *; @use "components/parallax";
html,body,#__next{height:100%} *{box-sizing:border-box} body{margin:0;background:$bg;color:$text;font-family:ui-sans-serif,system-ui}
button{ @include button(); } a.button{ @include button(#374151); text-decoration:none; display:inline-block; }
input,textarea{ width:100%; background:#111; color:$text; border:1px solid $border; border-radius:8px; padding:.5rem .75rem; }
.panel{ @include card; } .text-muted{ color:$muted }
EOF

# Parallax component
cat > frontend/components/Parallax.tsx <<'EOF'
import { useEffect, useRef } from "react";
export default function Parallax({ title="Wallet Recovery", subtitle="PGP-first • Admin-approved • Credits", children }:{
  title?:string; subtitle?:string; children?:React.ReactNode;
}) {
  const a = useRef<HTMLDivElement|null>(null), b = useRef<HTMLDivElement|null>(null);
  useEffect(()=>{ const h=()=>{ const y=window.scrollY||0; if(a.current) a.current.style.transform=`translateY(${Math.min(40,y*.08)}px)`;
    if(b.current){ b.current.style.transform=`translateY(${Math.min(30,y*.05)}px)`; b.current.style.opacity=String(Math.max(.25,.55-y/1400));}};
    h(); window.addEventListener("scroll",h,{passive:true}); return ()=>window.removeEventListener("scroll",h);},[]);
  return (<section className="parallax-root">
    <div ref={a} className="parallax-layer parallax-stars" />
    <div ref={b} className="parallax-layer parallax-gradient" />
    <div className="parallax-content"><div><h1 style={{fontSize:"2rem",marginBottom:8}}>{title}</h1>
      <p className="text-muted" style={{marginBottom:16}}>{subtitle}</p>{children}</div></div></section>);
}
EOF

# API client
cat > frontend/lib/api.ts <<'EOF'
import axios from "axios";
const api = axios.create({ withCredentials: true, baseURL: process.env.NEXT_PUBLIC_API_BASE || "" });
export default api;
EOF

# Next pages
cat > frontend/pages/_app.tsx <<'EOF'
import type { AppProps } from "next/app";
import "../styles/globals.scss";
export default function App({ Component, pageProps }: AppProps) { return <Component {...pageProps} />; }
EOF

cat > frontend/pages/index.tsx <<'EOF'
import Parallax from "../components/Parallax";
export default function Home(){
  return (<>
    <Parallax subtitle="Secure, watch-only recovery scanning.">
      <a className="button" href="/login">Sign in with PGP</a>
    </Parallax>
    <main style={{maxWidth:960,margin:"40px auto",padding:"0 16px"}}>
      <div className="panel"><h2 style={{marginTop:0}}>Welcome</h2>
        <p className="text-muted">This build ships SCSS and a lightweight parallax header. PGP auth lands in Step 2; scanning in Step 3.</p>
      </div>
    </main>
  </>);
}
EOF

# Minimal login page (modal added in Step 3)
cat > frontend/pages/login.tsx <<'EOF'
import { useState } from "react";
export default function Login(){ const [open,setOpen]=useState(false);
  return (<>
    <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:"24px"}}>
      <div className="panel" style={{maxWidth:560}}>
        <h1>Sign In with PGP</h1>
        <p className="text-muted">Admin-approved keys only. Classic login is disabled.</p>
        <div style={{display:"flex",gap:12}}><button onClick={()=>setOpen(true)}>Open PGP Modal</button>
          <a className="button" href="/register" style={{background:"#374151"}}>Request Access</a></div>
        {open && <div style={{marginTop:12,opacity:.8}}>Modal arrives in Step 3.</div>}
      </div>
    </main>
  </>);
}
EOF

# Register placeholder (wired in Step 3)
cat > frontend/pages/register.tsx <<'EOF'
export default function Register(){ return (
  <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:"24px"}}>
    <div className="panel" style={{maxWidth:720}}>
      <h1>Request Access</h1>
      <p className="text-muted">Step 3 wires this page to submit your display name, email and PGP public key for admin approval.</p>
    </div>
  </main>
);}
EOF

# --- Frontend Dockerfile ------------------------------------------------------
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

# --- docker-compose (no 'version' key) ---------------------------------------
cat > docker-compose.yml <<'EOF'
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

mkdir -p deploy
cat > deploy/nginx.conf <<'EOF'
server {
  listen 80; server_name _;
  client_max_body_size 10m;
  location /api/ {
    proxy_pass http://backend:8000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
  location / { proxy_pass http://frontend:3000/; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; }
}
EOF

# --- .gitignore ---------------------------------------------------------------
cat > .gitignore <<'EOF'
node_modules/
.next/
dist/
frontend/.next/
frontend/node_modules/
backend/venv/
__pycache__/
*.pyc
.DS_Store
.env
EOF

echo "✅ Step 1 complete."
echo "Next: docker compose up --build   (frontend: http://localhost:3000 , backend: http://localhost:8000/health)"

