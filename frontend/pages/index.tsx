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
