#!/usr/bin/env bash
set -euo pipefail

[ -d frontend ] || { echo "frontend/ missing. run init_step_one.sh first."; exit 1; }

echo "== Ensuring 'sass' is installed (Next.js SCSS support) =="
cd frontend
# add devDependency "sass" if missing
node -e "
const fs=require('fs'); const p='package.json';
const pkg=JSON.parse(fs.readFileSync(p,'utf8'));
pkg.devDependencies ??= {};
if(!pkg.devDependencies.sass){ pkg.devDependencies.sass='^1.77.0'; fs.writeFileSync(p,JSON.stringify(pkg,null,2)); console.log('Added sass to devDependencies'); }
"
npm install
cd ..

echo "== Creating SCSS structure =="
mkdir -p frontend/styles frontend/styles/components frontend/styles/utils

# Variables & mixins
cat > frontend/styles/utils/_variables.scss <<'SCSS'
$bg: #0a0a0a;
$panel: #121212;
$border: #222;
$text: #f5f5f5;
$brand: #4f46e5;
$muted: #9ca3af;
$success: #34d399;
$error: #f87171;
$radius: 12px;
$shadow: 0 10px 40px rgba(0,0,0,.35);
SCSS

cat > frontend/styles/utils/_mixins.scss <<'SCSS'
@mixin card {
  background: $panel; border:1px solid $border; border-radius:$radius; padding:24px; box-shadow:$shadow;
}

@mixin button($bg:$brand,$fg:#fff){
  background:$bg; color:$fg; border:0; border-radius:8px; padding:.6rem 1rem; cursor:pointer;
}
SCSS

# Parallax styles
cat > frontend/styles/components/_parallax.scss <<'SCSS'
.parallax-root {
  position: relative;
  height: 50vh;
  min-height: 340px;
  overflow: clip;
  perspective: 1px; /* establish 3D context for subtle depth */
  background: linear-gradient(180deg, rgba(18,18,18,1) 0%, rgba(10,10,10,1) 100%);
}

.parallax-layer {
  position: absolute; inset: 0;
  transform-origin: center;
  will-change: transform, opacity;
}

.parallax-stars {
  background-image:
    radial-gradient(2px 2px at 20% 30%, rgba(255,255,255,.45) 50%, transparent 51%),
    radial-gradient(1.5px 1.5px at 70% 60%, rgba(255,255,255,.35) 50%, transparent 51%),
    radial-gradient(1px 1px at 45% 80%, rgba(255,255,255,.25) 50%, transparent 51%);
  background-repeat: repeat;
  background-size: 400px 300px, 360px 320px, 300px 280px;
  opacity:.5;
}

.parallax-gradient {
  background: radial-gradient(1200px 500px at 50% 130%, rgba(79,70,229,.25), transparent 60%);
  mix-blend-mode: screen;
}

.parallax-content {
  position: relative;
  z-index: 5;
  height: 100%;
  display: grid;
  place-items: center;
  text-align: center;
  padding: 1rem;
}
SCSS

# Global SCSS
cat > frontend/styles/globals.scss <<'SCSS'
@use "utils/variables" as *;
@use "utils/mixins" as *;
@use "components/parallax";

html,body,#__next{ height:100% }
*{ box-sizing:border-box }
body{ margin:0; background:$bg; color:$text; font-family: ui-sans-serif, system-ui; }

button{ @include button(); }
a.button{ @include button(#374151); text-decoration:none; display:inline-block; }

input,textarea{
  width:100%; background:#111; color:$text; border:1px solid $border; border-radius:8px; padding:.5rem .75rem;
}

.panel{ @include card; }

.text-muted{ color:$muted }
.text-success{ color:$success }
.text-error{ color:$error }
SCSS

# Parallax React component
cat > frontend/components/Parallax.tsx <<'TSX'
import { useEffect, useRef } from "react";

/**
 * Lightweight parallax: adjusts transform based on scroll progress.
 * No external libs; works on desktop & mobile.
 */
export default function Parallax({
  title = "Multi-Chain Wallet Recovery",
  subtitle = "Secure. Admin-approved PGP access.",
  children
}: { title?: string; subtitle?: string; children?: React.ReactNode }) {
  const starsRef = useRef<HTMLDivElement|null>(null);
  const glowRef = useRef<HTMLDivElement|null>(null);

  useEffect(()=>{
    const onScroll = () => {
      const y = window.scrollY || 0;
      // gentle parallax factors
      const starT = Math.min(40, y * 0.08);
      const glowT = Math.min(30, y * 0.05);
      if(starsRef.current){
        starsRef.current.style.transform = `translateY(${starT}px)`;
        starsRef.current.style.opacity = String(Math.max(0.35, 0.6 - y/1200));
      }
      if(glowRef.current){
        glowRef.current.style.transform = `translateY(${glowT}px)`;
        glowRef.current.style.opacity = String(Math.max(0.25, 0.55 - y/1400));
      }
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  },[]);

  return (
    <section className="parallax-root">
      <div ref={starsRef} className="parallax-layer parallax-stars" />
      <div ref={glowRef} className="parallax-layer parallax-gradient" />
      <div className="parallax-content">
        <div>
          <h1 style={{fontSize:"2rem", marginBottom:8}}>{title}</h1>
          <p className="text-muted" style={{marginBottom:16}}>{subtitle}</p>
          {children}
        </div>
      </div>
    </section>
  );
}
TSX

# Make sure _app imports SCSS (replace CSS import if present)
cat > frontend/pages/_app.tsx <<'TSX'
import type { AppProps } from "next/app";
import "../styles/globals.scss";
export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
TSX

# Update /index to show hero + CTA to /login
cat > frontend/pages/index.tsx <<'TSX'
import Parallax from "../components/Parallax";

export default function Home(){
  return (
    <>
      <Parallax
        subtitle="PGP-first authentication • Admin approval • Credits-based sessions"
      >
        <a className="button" href="/login">Sign in with PGP</a>
      </Parallax>

      <main style={{maxWidth:960, margin:"40px auto", padding:"0 16px"}}>
        <div className="panel">
          <h2 style={{marginTop:0}}>Welcome</h2>
          <p className="text-muted">
            This build uses SCSS and a lightweight parallax header.
            Authentication is PGP-based and admin-gated (Step 2), and the scanning UI lands in Step 4.
          </p>
        </div>
      </main>
    </>
  );
}
TSX

# Refresh /login to include parallax header, keep modal logic from Step 2
# (If you already have the modal file from earlier, this keeps it intact.)
if [ -f frontend/components/PGPLoginModal.tsx ]; then
  cat > frontend/pages/login.tsx <<'TSX'
import { useState } from "react";
import dynamic from "next/dynamic";
import Parallax from "../components/Parallax";

const PGPLoginModal = dynamic(()=>import("../components/PGPLoginModal"), { ssr:false });

export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <>
      <Parallax subtitle="Decrypt the challenge with your private key to authenticate." >
        <div style={{display:"flex",gap:12,justifyContent:"center"}}>
          <button onClick={()=>setOpen(true)}>Begin PGP Login</button>
          <a className="button" href="/register" style={{background:"#374151"}}>Request Access</a>
        </div>
      </Parallax>

      <main style={{maxWidth:720, margin:"24px auto", padding:"0 16px"}}>
        <div className="panel">
          <h2 style={{marginTop:0}}>Sign In</h2>
          <p className="text-muted">Admin-approved keys only. Each successful login consumes one credit.</p>
          <div style={{display:"flex",gap:12}}>
            <button onClick={()=>setOpen(true)}>Open PGP Modal</button>
            <a className="button" href="/register" style={{background:"#374151"}}>Request Access</a>
          </div>
        </div>
      </main>
      {open && <PGPLoginModal onClose={()=>setOpen(false)} />}
    </>
  );
}
TSX
fi

echo "== SCSS + Parallax added. Rebuild the frontend container =="
echo "   docker compose build --no-cache frontend && docker compose up -d"
