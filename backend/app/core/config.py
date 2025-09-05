import os
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = os.getenv("PROJECT_NAME","wallet-recovery")
    API_BASE: str = os.getenv("API_BASE","/api")
    MONGO_URI: str = os.getenv("MONGO_URI","mongodb://mongo:27017/wallet_recovery_db")
    MONGO_DB: str = os.getenv("MONGO_DB","wallet_recovery_db")
    JWT_SECRET: str = os.getenv("JWT_SECRET","changeme")
    JWT_EXPIRES_SECONDS: int = int(os.getenv("JWT_EXPIRES_SECONDS","3600"))
    SECURE_COOKIES: bool = os.getenv("SECURE_COOKIES","false").lower()=="true"
    ADMIN_BOOTSTRAP_TOKEN: str = os.getenv("ADMIN_BOOTSTRAP_TOKEN","")
    PGP_ENABLE: bool = os.getenv("PGP_ENABLE","true").lower() == "true"
    GPG_HOME: str = os.getenv("GPG_HOME","/app/.gnupg")
    GPG_KEYSERVER: str = os.getenv("GPG_KEYSERVER","hkps://keys.openpgp.org")
    BLOCKCHAIR_API_KEY: str = os.getenv("BLOCKCHAIR_API_KEY","")

settings = Settings()
