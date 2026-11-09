from __future__ import annotations

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import UserRow
from app.services.auth import decode_token

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> UserRow:
    if creds is None or not creds.credentials:
        raise HTTPException(401, "not authenticated")
    try:
        payload = decode_token(creds.credentials)
        uid = payload.get("sub")
    except Exception:
        raise HTTPException(401, "invalid token")
    user = db.get(UserRow, uid)
    if not user:
        raise HTTPException(401, "user not found")
    return user


def get_optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> UserRow | None:
    if creds is None or not creds.credentials:
        return None
    try:
        payload = decode_token(creds.credentials)
        return db.get(UserRow, payload.get("sub"))
    except Exception:
        return None
