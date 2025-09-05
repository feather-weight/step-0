#!/usr/bin/env bash
set -euo pipefail

# ==== Backend PGP auth routes & admin API ====
cat > backend/app/api/routes_auth_pgp.py <<'EOF'
from fastapi import APIRouter, HTTPException, Response
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
from jose import jwt
import secrets
from app.core.config import settings
from app.db.client import db
from bson import ObjectId
from pgpy import PGPKey, PGPMessage

router = APIRouter()

# In-memory challenge store; replace with Redis in prod
_challenges = {}

class RegisterRequest(BaseModel):
    name: str
    email: str
    public_key: str

class LoginStart(BaseModel):
    public_key: str

class LoginVerify(BaseModel):
    user_id: str
    token_response: str

@router.post("/register")
async def register(req: RegisterRequest):
    if await db.users.find_one({"email": req.email}):
        raise HTTPException(status_code=400, detail="Email already registered.")
    await db.users.insert_one({
        "name": req.name,
        "email": req.email,
        "public_key": req.public_key,
        "active": False,
        "credits": 0,
        "created_at": datetime.utcnow(),
        "roles": ["user"]
    })
    return {"message": "Registration submitted. Pending admin approval."}

@router.post("/login/start")
async def login_start(body: LoginStart):
    user = await db.users.find_one({"public_key": body.public_key, "active": True})
    if not user:
        raise HTTPException(status_code=400, detail="Invalid key or inactive account.")
    token = secrets.token_hex(16)
    # Encrypt challenge with user's public key (PGPy)
    try:
        user_pub, _ = PGPKey.from_blob(user["public_key"])
        msg = PGPMessage.new(token)
        enc = user_pub.encrypt(msg)
        armored = str(enc)
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to encrypt challenge.")
    _challenges[str(user["_id"])] = {"token": token, "exp": datetime.utcnow() + timedelta(minutes=5)}
    return {"user_id": str(user["_id"]), "challenge": armored}

@router.post("/login/verify")
async def login_verify(body: LoginVerify, response: Response):
    entry = _challenges.get(body.user_id)
    if not entry or entry["exp"] < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Challenge expired or not found.")
    if body.token_response != entry["token"]:
        raise HTTPException(status_code=400, detail="Invalid token response.")
    user = await db.users.find_one({"_id": ObjectId(body.user_id), "active": True})
    if not user:
        raise HTTPException(status_code=400, detail="User not found.")
    if int(user.get("credits", 0)) < 1:
        raise HTTPException(status_code=403, detail="No login credits; contact admin.")
    await db.users.update_one({"_id": user["_id"]}, {"$inc": {"credits": -1}})
    payload = {"sub": str(user["_id"]), "exp": datetime.utcnow() + timedelta(seconds=int(settings.JWT_EXPIRES_SECONDS))}
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")
    response.set_cookie("token", token, httponly=True, max_age=int(settings.JWT_EXPIRES_SECONDS), secure=False, samesite="Lax")
    _challenges.pop(body.user_id, None)
    return {"message": "Login successful"}
EOF

cat > backend/app/api/routes_admin.py <<'EOF'
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime
from app.db.client import db
from app.models.user import AdminUserInsert
from bson import ObjectId

router = APIRouter()

# TODO: Replace with real admin auth dependency
def admin_required():
    return True

class CreditAdjust(BaseModel):
    user_id: str
    delta: int

@router.post("/users/approve", dependencies=[Depends(admin_required)])
async def approve_user(user: AdminUserInsert):
    existing = await db.users.find_one({"email": user.email})
    if existing:
        await db.users.update_one({"_id": existing["_id"]}, {"$set": {
            "name": user.name,
            "public_key": user.public_key,
            "active": user.active,
            "credits": user.credits,
            "approved_at": datetime.utcnow()
        }})
        return {"message": "User updated & approved"}
    res = await db.users.insert_one({
        "name": user.name, "email": user.email, "public_key": user.public_key,
        "active": user.active, "credits": user.credits, "roles": ["user"], "approved_at": datetime.utcnow()
    })
    return {"message": "User created & approved", "user_id": str(res.inserted_id)}

@router.post("/users/credits", dependencies=[Depends(admin_required)])
async def adjust_credits(body: CreditAdjust):
    uid = ObjectId(body.user_id)
    await db.users.update_one({"_id": uid}, {"$inc": {"credits": body.delta}})
    u = await db.users.find_one({"_id": uid})
    return {"user_id": body.user_id, "credits": int(u["credits"])}
EOF

# Simple JWT protect dependency for later (reuse for scans, etc.)
cat > backend/app/core/security.py <<'EOF'
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from app.core.config import settings
from app.db.client import db
from bson import ObjectId

bearer = HTTPBearer(auto_error=False)

async def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)):
    token = None
    if creds and creds.scheme.lower() == "bearer":
        token = creds.credentials
    if not token:
        # also allow cookie "token" via frontend; this dependency is header-based
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
        uid = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await db.users.find_one({"_id": ObjectId(uid), "active": True})
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
EOF

echo "Step 2 (PGP auth backend) complete."

