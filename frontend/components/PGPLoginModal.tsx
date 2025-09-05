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
