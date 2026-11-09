"""회원가입/로그인 테스트."""

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine, init_db
from app.main import app
from app.services.auth import hash_password, verify_password


def test_password_hash_roundtrip():
    h = hash_password("secret123")
    assert verify_password("secret123", h)
    assert not verify_password("wrong", h)


def test_signup_login_me(tmp_path, monkeypatch):
    # 격리된 sqlite
    db_url = f"sqlite:///{tmp_path/'test.db'}"
    monkeypatch.setenv("DATABASE_URL", db_url)
    # recreate engine bindings for test — use app's init
    from app import database as dbmod
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    eng = create_engine(db_url, connect_args={"check_same_thread": False})
    TestingSession = sessionmaker(bind=eng, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=eng)

    def override_get_db():
        s = TestingSession()
        try:
            yield s
        finally:
            s.close()

    from app.database import get_db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    r = client.post(
        "/auth/signup",
        json={"email": "jaehyun@example.com", "password": "pass1234", "name": "재현", "phone": "010-1111-2222"},
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert "access_token" in data
    assert data["user"]["email"] == "jaehyun@example.com"

    r2 = client.post("/auth/login", json={"email": "jaehyun@example.com", "password": "pass1234"})
    assert r2.status_code == 200
    token = r2.json()["access_token"]

    r3 = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r3.status_code == 200
    assert r3.json()["name"] == "재현"

    # lost dog linked to user
    r4 = client.post(
        "/api/v1/lost-dogs",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "breed": "말티즈",
            "color": "흰색",
            "features": "빨간 목걸이",
            "age": "3살",
            "lost_date": "2026-10-28",
            "lost_lat": 37.5665,
            "lost_lng": 126.9780,
            "lost_address": "서울 중구",
        },
    )
    assert r4.status_code == 201, r4.text
    assert r4.json().get("user_id") == data["user"]["id"]

    app.dependency_overrides.clear()
