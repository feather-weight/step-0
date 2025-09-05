from pydantic import BaseModel, EmailStr, Field
from typing import Optional

class UserCreateRequest(BaseModel):
    name: str
    email: EmailStr
    public_key: str

class UserPublic(BaseModel):
    id: str = Field(alias="_id")
    name: str
    email: EmailStr
    active: bool
    credits: int

class AdminUserInsert(BaseModel):
    name: str
    email: EmailStr
    public_key: str
    active: bool = True
    credits: int = 1
