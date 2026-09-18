from pydantic import BaseModel, EmailStr, Field

VALID_ROLES = "^(admin|user|guest)$"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    role: str = Field("user", pattern=VALID_ROLES)


class UserUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    email: EmailStr | None = None
    role: str | None = Field(None, pattern=VALID_ROLES)


class UserOut(BaseModel):
    id: int
    name: str
    email: str
    role: str

    model_config = {"from_attributes": True}


class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    price: float = Field(..., gt=0)
    stock: int = Field(0, ge=0)


class ItemUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    price: float | None = Field(None, gt=0)
    stock: int | None = Field(None, ge=0)


class ItemOut(BaseModel):
    id: int
    name: str
    price: float
    stock: int

    model_config = {"from_attributes": True}