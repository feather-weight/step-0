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
