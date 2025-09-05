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
