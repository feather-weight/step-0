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
