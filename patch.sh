# patch_frontend_for_step2.sh
cat > patch_frontend_for_step2.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ -d frontend ] || { echo "frontend/ missing. run init_step_one.sh first."; exit 1; }

mkdir -p frontend/{pages,components,lib,styles}

# API client (uses NEXT_PUBLIC_API_BASE if set; otherwise same-origin via nginx)
cat > frontend/lib/api.ts <<'TS'
import axios from "axios";
const api = axios.create({
  withCredentials: true,
  baseURL: process.env.NEXT_PUBLIC_API_BASE || ""
});
export default api;
TS

# _app.tsx (loads global styles)
cat > frontend/pages/_app.tsx <<'TSX'
import type { AppProps } from "next/app";
import "../styles/globals.css";
export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
TSX

# styles
cat > frontend/styles/globals.css <<'CSS'
html,body,#__next{height:100%}
body{margin:0;background:#0a0a0a;color:#f5f5f5;font-family:ui-sans-serif,system-ui}
button{background:#4f46e5;color:#fff;border:0;border-radius:8px;padding:.6rem 1rem;cursor:pointer}
input,textarea{width:100%;background:#111;color:#f5f5f5;border:1px solid #222;border-radius:8px;padding:.5rem .75rem}
a.button{display:inline-block;text-decoration:none}
CSS

# index redirects to /login
cat > frontend/pages/index.tsx <<'TSX'
import { useEffect } from "react";
export default function Home(){ useEffect(()=>{ window.location.href="/login"; },[]); return null; }
TSX

# Register page (submits to /api/auth/register)
cat > frontend/pages/register.tsx <<'TSX'
import { useState } from "react";
import api from "../lib/api";

export default function RegisterPage() {
  const [name,setName]=useState("");
  const [email,setEmail]=useState("");
  const [publicKey,setPublicKey]=useState("");
  const [msg,setMsg]=useState<string|null>(null);
  const [err,setErr]=useState<string|null>(null);

  const submit = async (e:any)=>{
    e.preventDefault(); setErr(null); setMsg(null);
    try{
      await api.post("/api/auth/register",{name,email,public_key:publicKey});
      setMsg("Submitted. Pending admin approval.");
      setName(""); setEmail(""); setPublicKey("");
    }catch(e:any){
      setErr(e?.response?.data?.detail || "Registration failed");
    }
  };

  return (
    <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:"24px"}}>
      <div style={{maxWidth:720,width:"100%",background:"#121212",border:"1px solid #222",borderRadius:12,padding:24}}>
        <h1>Request Access</h1>
        <p style={{opacity:.8}}>Submit name, email, and PGP public key. Admin must approve before you can log in.</p>
        <form onSubmit={submit} style={{display:"grid",gap:12}}>
          <div><label>Name</label><input value={name} onChange={e=>setName(e.target.value)} required /></div>
          <div><label>Email</label><input value={email} onChange={e=>setEmail(e.target.value)} type="email" required /></div>
          <div><label>PGP public key</label><textarea rows={10} value={publicKey} onChange={e=>setPublicKey(e.target.value)} required /></div>
          <div style={{display:"flex",gap:12}}>
            <button type="submit">Submit</button>
            <a className="button" href="/login" style={{background:"#374151"}}>Back to Login</a>
          </div>
        </form>
        {msg && <p style={{color:"#34d399"}}>{msg}</p>}
        {err && <p style={{color:"#f87171"}}>{err}</p>}
      </div>
    </main>
  );
}
TSX

# PGP login modal wired to /api/auth/login/start + /verify
cat > frontend/components/PGPLoginModal.tsx <<'TSX'
import { useState } from "react";
import api from "../lib/api";

export default function PGPLoginModal({onClose}:{onClose:()=>void}) {
  const [pub,setPub]=useState("");
  const [userId,setUserId]=useState<string>("");
  const [challenge,setChallenge]=useState<string>("");
  const [tokenResp,setTokenResp]=useState("");
  const [phase,setPhase]=useState<"start"|"verify">("start");
  const [err,setErr]=useState<string|null>(null);
  const [ok,setOk]=useState<string|null>(null);

  const begin = async ()=>{
    try{
      setErr(null); setOk(null);
      const {data} = await api.post("/api/auth/login/start",{public_key: pub});
      setUserId(data.user_id); setChallenge(data.challenge); setPhase("verify");
    }catch(e:any){ setErr(e?.response?.data?.detail || "Login start failed"); }
  };

  const verify = async ()=>{
    try{
      setErr(null); setOk(null);
      await api.post("/api/auth/login/verify",{user_id:userId, token_response: tokenResp});
      setOk("Authenticated! Redirecting…");
      setTimeout(()=>{ window.location.href="/dashboard"; }, 600);
    }catch(e:any){ setErr(e?.response?.data?.detail || "Verification failed"); }
  };

  return (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",display:"grid",placeItems:"center",padding:16}}>
      <div style={{width:"100%",maxWidth:720,background:"#121212",border:"1px solid #222",borderRadius:12,padding:24}}>
        <h2>PGP Login</h2>
        {phase==="start" && (
          <>
            <p style={{opacity:.8}}>Paste your PGP <b>public</b> key to receive an encrypted challenge.</p>
            <textarea rows={8} value={pub} onChange={e=>setPub(e.target.value)} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" />
            <div style={{display:"flex",gap:12,marginTop:12}}>
              <button onClick={begin}>Get Challenge</button>
              <button style={{background:"#374151"}} onClick={onClose}>Cancel</button>
            </div>
          </>
        )}
        {phase==="verify" && (
          <>
            <p style={{opacity:.8}}>Decrypt the message, paste the plaintext token below, then verify.</p>
            <pre style={{whiteSpace:"pre-wrap",background:"#181818",padding:12,borderRadius:8}}>{challenge}</pre>
            <input value={tokenResp} onChange={e=>setTokenResp(e.target.value)} placeholder="Decrypted token" />
            <div style={{display:"flex",gap:12,marginTop:12}}>
              <button onClick={verify}>Verify</button>
              <button style={{background:"#374151"}} onClick={onClose}>Close</button>
            </div>
          </>
        )}
        {err && <p style={{color:"#f87171"}}>{err}</p>}
        {ok && <p style={{color:"#34d399"}}>{ok}</p>}
      </div>
    </div>
  );
}
TSX

# Login page that uses the modal
cat > frontend/pages/login.tsx <<'TSX'
import { useState } from "react";
import dynamic from "next/dynamic";
const PGPLoginModal = dynamic(()=>import("../components/PGPLoginModal"), { ssr:false });

export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:"24px"}}>
      <div style={{maxWidth:560,width:"100%",background:"#121212",border:"1px solid #222",borderRadius:12,padding:24}}>
        <h1>Sign In with PGP</h1>
        <p style={{opacity:.8}}>Admin-approved keys only. Each successful login consumes one credit.</p>
        <div style={{display:"flex",gap:12,marginTop:12}}>
          <button onClick={()=>setOpen(true)}>Begin PGP Login</button>
          <a className="button" href="/register" style={{background:"#374151"}}>Request Access</a>
        </div>
      </div>
      {open && <PGPLoginModal onClose={()=>setOpen(false)} />}
    </main>
  );
}
TSX

# Protected dashboard placeholder
cat > frontend/pages/dashboard.tsx <<'TSX'
export default function Dashboard(){
  return (
    <main style={{minHeight:"100vh",padding:"24px"}}>
      <div style={{maxWidth:960,margin:"0 auto"}}>
        <h1>Dashboard</h1>
        <p style={{opacity:.8}}>Authenticated area. Scanning UI lands here in Step 4.</p>
      </div>
    </main>
  );
}
TSX

# Next config
cat > frontend/next.config.mjs <<'JS'
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true, output: 'standalone' };
export default nextConfig;
JS

# tsconfig (if missing)
cat > frontend/tsconfig.json <<'JSON'
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
JSON

echo "Frontend patched for Step 2 compatibility."
EOF

chmod +x patch_frontend_for_step2.sh
./patch_frontend_for_step2.sh

