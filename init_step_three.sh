#!/usr/bin/env bash
set -euo pipefail

mkdir -p frontend/pages frontend/components frontend/lib frontend/styles

# Basic API client
cat > frontend/lib/api.ts <<'EOF'
import axios from "axios";
const api = axios.create({ withCredentials: true, baseURL: process.env.NEXT_PUBLIC_API_BASE || "" });
export default api;
EOF

# Registration page -> sends request but does not auto-activate
cat > frontend/pages/register.tsx <<'EOF'
import { useState } from "react";
import api from "../lib/api";

export default function RegisterPage() {
  const [name,setName]=useState("");
  const [email,setEmail]=useState("");
  const [publicKey,setPublicKey]=useState("");
  const [msg,setMsg]=useState<string|null>(null);
  const [err,setErr]=useState<string|null>(null);

  const submit = async (e:any)=>{
    e.preventDefault();
    setErr(null); setMsg(null);
    try{
      await api.post("/api/auth/register",{name,email,public_key:publicKey});
      setMsg("Submitted. Pending admin approval.");
      setName(""); setEmail(""); setPublicKey("");
    }catch(e:any){
      setErr(e?.response?.data?.detail || "Registration failed");
    }
  };

  return (
    <div style={{maxWidth:720,margin:"3rem auto"}}>
      <h1>Request Access</h1>
      <p>Submit your display name, email, and PGP public key. An admin will review and approve.</p>
      <form onSubmit={submit}>
        <input value={name} onChange={e=>setName(e.target.value)} placeholder="Display name" required />
        <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email" required type="email"/>
        <textarea value={publicKey} onChange={e=>setPublicKey(e.target.value)} placeholder="ASCII-armored PGP public key" rows={10} required />
        <button type="submit">Submit</button>
      </form>
      {msg && <p style={{color:"green"}}>{msg}</p>}
      {err && <p style={{color:"crimson"}}>{err}</p>}
    </div>
  )
}
EOF

# PGP Login Modal
cat > frontend/components/PGPLoginModal.tsx <<'EOF'
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
      setErr(null);
      const {data} = await api.post("/api/auth/login/start",{public_key: pub});
      setUserId(data.user_id);
      setChallenge(data.challenge);
      setPhase("verify");
    }catch(e:any){
      setErr(e?.response?.data?.detail || "Login start failed");
    }
  };

  const verify = async ()=>{
    try{
      setErr(null);
      const {data} = await api.post("/api/auth/login/verify",{user_id:userId, token_response: tokenResp});
      setOk("Authenticated! Cookie set. Redirecting…");
      setTimeout(()=>window.location.href="/dashboard", 800);
    }catch(e:any){
      setErr(e?.response?.data?.detail || "Verification failed");
    }
  };

  return (
    <div style={{position:"fixed", inset:0, background:"rgba(0,0,0,.5)"}}>
      <div style={{maxWidth:700, margin:"10vh auto", background:"#111", color:"#fff", padding:"1.5rem", borderRadius:12}}>
        <h2>PGP Login</h2>
        {phase==="start" && (
          <>
            <p>Paste your PGP <b>public</b> key to receive an encrypted challenge.</p>
            <textarea rows={8} value={pub} onChange={e=>setPub(e.target.value)} placeholder="PGP public key" />
            <div style={{display:"flex", gap:8}}>
              <button onClick={begin}>Get Challenge</button>
              <button onClick={onClose}>Cancel</button>
            </div>
          </>
        )}
        {phase==="verify" && (
          <>
            <p>Decrypt the message below with your private key, then paste the result (token) and submit.</p>
            <pre style={{whiteSpace:"pre-wrap", background:"#222", padding:"1rem", borderRadius:8}}>{challenge}</pre>
            <input value={tokenResp} onChange={e=>setTokenResp(e.target.value)} placeholder="Decrypted token" />
            <div style={{display:"flex", gap:8}}>
              <button onClick={verify}>Verify</button>
              <button onClick={onClose}>Close</button>
            </div>
          </>
        )}
        {err && <p style={{color:"salmon"}}>{err}</p>}
        {ok && <p style={{color:"lightgreen"}}>{ok}</p>}
      </div>
    </div>
  );
}
EOF

# Login page that invokes the modal
cat > frontend/pages/login.tsx <<'EOF'
import { useState } from "react";
import dynamic from "next/dynamic";

const PGPLoginModal = dynamic(()=>import("../components/PGPLoginModal"),{ssr:false});

export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <div style={{maxWidth:720, margin:"3rem auto"}}>
      <h1>Sign In with PGP</h1>
      <p>Admin-approved PGP keys only. Each successful login consumes one credit.</p>
      <button onClick={()=>setOpen(true)}>Begin PGP Login</button>
      {open && <PGPLoginModal onClose={()=>setOpen(false)} />}
    </div>
  )
}
EOF

# Protected dashboard example
cat > frontend/pages/dashboard.tsx <<'EOF'
import { useEffect } from "react";

export default function Dashboard(){
  useEffect(()=>{
    // optional client check; rely on server protection for APIs
  },[]);
  return <div style={{maxWidth:920, margin:"3rem auto"}}><h1>Dashboard</h1><p>Authenticated area.</p></div>
}
EOF

# Minimal index redirect
cat > frontend/pages/index.tsx <<'EOF'
import { useEffect } from "react";
export default function Home(){ useEffect(()=>{ window.location.href="/login"; },[]); return null; }
EOF

echo "Step 3 (PGP auth frontend) complete."

