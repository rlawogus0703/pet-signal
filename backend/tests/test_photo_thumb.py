"""공고·실종견 사진 미리보기(size=thumb / w=). 매칭·임베딩은 건드리지 않습니다."""

from __future__ import annotations

import base64
import io
from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.ai import image_embedder
from app.database import get_db, init_db
from app.main import app
from app.models.db_models import NoticeRow
from app.services import image_index

ROOT = Path(__file__).resolve().parents[2]
DOGS = ROOT / "web" / "assets" / "dogs"


def _client(tmp_path, monkeypatch):
    image_index.clear_thumb_cache()
    monkeypatch.setattr(image_embedder, "CACHE_DIR", tmp_path / "image_cache")
    eng = create_engine(f"sqlite:///{tmp_path / 't.db'}", connect_args={"check_same_thread": False})
    TS = sessionmaker(bind=eng, autocommit=False, autoflush=False)
    init_db(eng)

    def override():
        s = TS()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override
    return TestClient(app), TS


def _rgba_png(width=800, height=500) -> bytes:
    im = Image.new("RGBA", (width, height), (20, 160, 80, 128))
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def test_make_thumbnail_converts_rgba_and_shrinks():
    src = _rgba_png(900, 600)
    out = image_index.make_thumbnail(src, max_side=400)
    assert out[:3] == b"\xff\xd8\xff"
    im = Image.open(io.BytesIO(out))
    assert im.format == "JPEG" and im.mode == "RGB"
    assert im.size == (400, 267)
    assert len(out) < len(src)


def test_notice_photo_thumb_smaller_than_original(tmp_path, monkeypatch):
    client, TS = _client(tmp_path, monkeypatch)
    try:
        photo = DOGS / "corgi.jpg"
        db = TS()
        today = date(2026, 11, 14)
        db.add(
            NoticeRow(
                notice_id="T1",
                source="animal_api",
                notice_no="서울-1",
                breed="웰시코기",
                color="갈색",
                found_date=today,
                found_lat=37.57,
                found_lng=126.98,
                notice_start=today,
                notice_end=today + timedelta(days=7),
                photo_url=str(photo),
                photo_url2=str(DOGS / "beagle.jpg"),
            )
        )
        db.commit()
        db.close()

        orig = client.get("/api/v1/notices/T1/photo")
        assert orig.status_code == 200
        assert orig.headers["content-type"] == "image/jpeg"
        assert orig.headers["cache-control"] == "public, max-age=86400"
        assert orig.content == photo.read_bytes()

        thumb = client.get("/api/v1/notices/T1/photo", params={"size": "thumb"})
        assert thumb.status_code == 200
        assert thumb.headers["content-type"] == "image/jpeg"
        assert thumb.headers["cache-control"] == "public, max-age=86400"
        assert thumb.content[:3] == b"\xff\xd8\xff"
        assert len(thumb.content) < len(orig.content)
        im = Image.open(io.BytesIO(thumb.content))
        assert im.mode == "RGB" and max(im.size) == 400

        # 원본은 그대로
        again = client.get("/api/v1/notices/T1/photo")
        assert again.content == orig.content

        # 알 수 없는 size 는 원본
        unk = client.get("/api/v1/notices/T1/photo", params={"size": "full"})
        assert unk.content == orig.content

        # w= 와 n=2 조합 (?n=2&size=thumb)
        t2 = client.get("/api/v1/notices/T1/photo", params={"n": 2, "size": "thumb", "w": 200})
        assert t2.status_code == 200
        im2 = Image.open(io.BytesIO(t2.content))
        assert max(im2.size) == 200
        assert t2.content != thumb.content
    finally:
        app.dependency_overrides.clear()
        image_index.clear_thumb_cache()


def test_thumb_memory_and_disk_cache(tmp_path, monkeypatch):
    client, TS = _client(tmp_path, monkeypatch)
    try:
        src = _rgba_png(640, 480)
        db = TS()
        today = date(2026, 11, 14)
        db.add(
            NoticeRow(
                notice_id="T2",
                source="animal_api",
                breed="믹스견",
                color="흰색",
                found_date=today,
                photo_url=str(tmp_path / "src.png"),
            )
        )
        (tmp_path / "src.png").write_bytes(src)
        db.commit()
        db.close()

        r1 = client.get("/api/v1/notices/T2/photo?size=thumb")
        assert r1.status_code == 200
        disk = list((tmp_path / "image_cache").glob("*.t400.jpg"))
        assert len(disk) == 1
        on_disk = disk[0].read_bytes()
        assert on_disk == r1.content

        # 디스크를 지워도 메모리 캐시에서 나옴
        disk[0].unlink()
        r2 = client.get("/api/v1/notices/T2/photo?size=thumb")
        assert r2.content == r1.content
        assert not disk[0].exists()

        # 메모리를 비우면 다시 만들어 디스크에 씀
        image_index.clear_thumb_cache()
        r3 = client.get("/api/v1/notices/T2/photo?size=thumb")
        assert r3.content == r1.content
        assert disk[0].is_file()
    finally:
        app.dependency_overrides.clear()
        image_index.clear_thumb_cache()


def test_lost_dog_photo_thumb(tmp_path, monkeypatch):
    client, _TS = _client(tmp_path, monkeypatch)
    # 업로드 경로도 테스트 임시 폴더로
    monkeypatch.setattr(image_index, "UPLOAD_DIR", tmp_path / "uploads")
    try:
        photo = (DOGS / "maltese_white.jpg").read_bytes()
        r = client.post(
            "/api/v1/lost-dogs",
            json=dict(
                photo_data="data:image/jpeg;base64," + base64.b64encode(photo).decode(),
                breed="말티즈",
                color="흰색",
                lost_date="2026-11-11",
                lost_lat=37.57,
                lost_lng=126.98,
            ),
        )
        assert r.status_code == 201, r.text
        url = r.json()["photo_proxy_url"]
        orig = client.get(url)
        thumb = client.get(url, params={"size": "thumb"})
        assert orig.status_code == 200 and thumb.status_code == 200
        assert orig.content == photo
        assert thumb.headers["content-type"] == "image/jpeg"
        assert len(thumb.content) < len(orig.content)
        im = Image.open(io.BytesIO(thumb.content))
        assert max(im.size) == 400
    finally:
        app.dependency_overrides.clear()
        image_index.clear_thumb_cache()
