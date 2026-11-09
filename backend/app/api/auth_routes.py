from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.auth_deps import get_current_user
from app.database import get_db
from app.models.db_models import UserRow
from app.models.schemas import AuthTokenOut, LoginRequest, SignupRequest, UserOut
from app.services.auth import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _user_out(u: UserRow) -> UserOut:
    return UserOut(
        id=u.id,
        email=u.email,
        name=u.name,
        phone=u.phone,
        created_at=u.created_at,
    )


@router.post("/signup", response_model=AuthTokenOut, status_code=201)
def signup(body: SignupRequest, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    if not email or "@" not in email:
        raise HTTPException(400, "invalid email")
    if len(body.password) < 4:
        raise HTTPException(400, "password too short")
    exists = db.scalars(select(UserRow).where(UserRow.email == email)).first()
    if exists:
        raise HTTPException(400, "email already registered")
    user = UserRow(
        id=str(uuid.uuid4()),
        email=email,
        password_hash=hash_password(body.password),
        name=body.name.strip(),
        phone=body.phone,
        created_at=_now(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(user_id=user.id, email=user.email)
    return AuthTokenOut(access_token=token, user=_user_out(user))


@router.post("/login", response_model=AuthTokenOut)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    user = db.scalars(select(UserRow).where(UserRow.email == email)).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "invalid email or password")
    token = create_access_token(user_id=user.id, email=user.email)
    return AuthTokenOut(access_token=token, user=_user_out(user))


@router.get("/me", response_model=UserOut)
def me(user: UserRow = Depends(get_current_user)):
    return _user_out(user)
