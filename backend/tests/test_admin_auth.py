"""관리자 API 키 보호 테스트."""

import pytest
from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app


@pytest.fixture(autouse=True)
def _clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_admin_collect_missing_key_forbidden():
    client = TestClient(app)
    r = client.post("/api/v1/admin/collect")
    assert r.status_code in (401, 403)


def test_admin_collect_disabled_when_key_unset(monkeypatch):
    monkeypatch.delenv("ADMIN_API_KEY", raising=False)
    get_settings.cache_clear()
    client = TestClient(app)
    r = client.post("/api/v1/admin/collect", headers={"X-Admin-Key": "anything"})
    assert r.status_code == 403


def test_admin_collect_wrong_key(monkeypatch):
    monkeypatch.setenv("ADMIN_API_KEY", "correct-test-key")
    get_settings.cache_clear()
    client = TestClient(app)
    r = client.post("/api/v1/admin/collect", headers={"X-Admin-Key": "wrong-key"})
    assert r.status_code == 403


def test_admin_collect_correct_key_accepted(monkeypatch):
    monkeypatch.setenv("ADMIN_API_KEY", "correct-test-key")
    get_settings.cache_clear()

    def fake_collect(db, pages=None, num_of_rows=None, embed_images=True):
        return {"ok": True, "fetched": 0, "upserted": 0}

    monkeypatch.setattr("app.api.routes.collect_notices", fake_collect)
    client = TestClient(app)
    r = client.post("/api/v1/admin/collect", headers={"X-Admin-Key": "correct-test-key"})
    assert r.status_code == 200
    assert r.json().get("ok") is True


def test_admin_seed_requires_key(monkeypatch):
    monkeypatch.setenv("ADMIN_API_KEY", "correct-test-key")
    get_settings.cache_clear()
    client = TestClient(app)
    assert client.post("/api/v1/admin/seed").status_code in (401, 403)
    assert client.post("/api/v1/admin/seed", headers={"X-Admin-Key": "wrong-key"}).status_code == 403

    monkeypatch.setattr("app.api.routes.seed_notices", lambda db: 0)
    r = client.post("/api/v1/admin/seed", headers={"X-Admin-Key": "correct-test-key"})
    assert r.status_code == 200
    assert r.json() == {"ok": True, "inserted": 0}
