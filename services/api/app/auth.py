import os
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .database import get_db
from .models import User
from .schemas import LoginRequest

router = APIRouter(prefix="/auth", tags=["authentication"])

security = HTTPBearer()

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-this")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60


def create_access_token(user: User) -> str:
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role,
        "iat": now,
        "exp": now + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="token has expired",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid token",
        )


@router.post("/login")
def login(body: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email).first()

    if not user or user.password != body.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid email or password",
        )

    access_token = create_access_token(user)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role,
        },
    }


@router.get("/validate")
def validate_token(
    response: Response,
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    payload = decode_access_token(credentials.credentials)

    response.headers["X-Auth-User"] = payload["sub"]
    response.headers["X-Auth-Email"] = payload["email"]
    response.headers["X-Auth-Role"] = payload["role"]

    return {
        "authenticated": True,
        "user_id": payload["sub"],
        "email": payload["email"],
        "role": payload["role"],
    }


@router.get("/authorize")
def authorize(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    payload = decode_access_token(credentials.credentials)

    role = payload["role"]
    path = request.headers.get("X-Original-URI", "")
    method = request.headers.get("X-Original-Method", request.method)

    # Admin boleh mengakses semua endpoint /api/*
    if role == "admin":
        return {
            "authorized": True,
            "role": role,
        }

    # User hanya boleh GET /api/items dan detail item
    if role == "user":
        if method == "GET" and (
            path == "/api/items"
            or path.startswith("/api/items/")
        ):
            return {
                "authorized": True,
                "role": role,
            }

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="insufficient permissions",
    )