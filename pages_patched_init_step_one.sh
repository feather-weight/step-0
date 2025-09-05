mkdir -p frontend/{pages,styles,components,lib}

# _app.tsx
cat > frontend/pages/_app.tsx <<'EOF'
import type { AppProps } from "next/app";
import "../styles/globals.css";
export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
EOF

# index.tsx
cat > frontend/pages/index.tsx <<'EOF'
export default function Home(){
  return (
    <main style={{minHeight:"100vh",display:"grid",placeItems:"center"}}>
      <div style={{textAlign:"center"}}>
        <h1>Multi-Chain Wallet Recovery</h1>
        <p>PGP login lives at /login (Step 3 wires it).</p>
      </div>
    </main>
  );
}
EOF

# login.tsx (so you have a second page now)
cat > frontend/pages/login.tsx <<'EOF'
import { useState } from "react";
export default function LoginPage(){
  const [open,setOpen]=useState(false);
  return (
    <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:"24px"}}>
      <div style={{maxWidth:560,width:"100%",background:"#121212",border:"1px solid #222",borderRadius:12,padding:24}}>
        <h1>Sign In with PGP</h1>
        <p style={{opacity:.8}}>Admin-approved PGP keys only. Classic login is disabled.</p>
        <button onClick={()=>setOpen(true)} style={{marginTop:12}}>Begin PGP Login</button>
        {open && <div style={{marginTop:12,opacity:.8,fontSize:14}}>Modal placeholder. Step 3 wires API calls.</div>}
      </div>
    </main>
  );
}
EOF

# basic styles (optional but nice)
cat > frontend/styles/globals.css <<'EOF'
html,body,#__next{height:100%}
body{margin:0;background:#0a0a0a;color:#f5f5f5;font-family:ui-sans-serif,system-ui}
button{background:#4f46e5;color:#fff;border:0;border-radius:8px;padding:.6rem 1rem;cursor:pointer}
input,textarea{width:100%;background:#111;color:#f5f5f5;border:1px solid #222;border-radius:8px;padding:.5rem .75rem}
EOF

# ensure next config exists
cat > frontend/next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true, output: 'standalone' };
export default nextConfig;
EOF

# minimal tsconfig (if missing)
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

