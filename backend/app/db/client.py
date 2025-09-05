from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

mongo = None
db = None

async def init_mongo():
    global mongo, db
    mongo = AsyncIOMotorClient(settings.MONGO_URI)
    db = mongo[settings.MONGO_DB]
    # Step 2/3 will create indexes
