from datetime import date

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models.db_models import NoticeRow
from app.services import collector
from app.services.image_index import embed_pending
from app.services.matching_service import matchable_notices
from app.services.notice_state import STALE_STATE
from app.sources.base import NoticeRecord, NoticeSource


def _rec(i: int, state: str) -> NoticeRecord:
    return NoticeRecord(
        notice_id=f"N{i}", source="animal_api", breed="말티즈", color="흰색", age="3살",
        features="소형", found_date=date(2026, 11, 1), found_lat=37.5, found_lng=127.0,
        photo_url=None, process_state="보호중", notice_start=date(2026, 11, 1),
    )


class PagedSource(NoticeSource):
    name = "animal_api"

    def __init__(self, notice_ids, protect_ids, fail_after=None):
        self.ids = {"notice": notice_ids, "protect": protect_ids}
        self.fail_after = fail_after
        self.calls = 0

    def iter_pages(self, *, rows, max_pages, states=None):
        for state, ids in self.ids.items():
            for p in range(0, max(1, len(ids)), rows):
                self.calls += 1
                if self.fail_after is not None and self.calls > self.fail_after:
                    raise RuntimeError("timeout")
                yield state, [_rec(i, state) for i in ids[p : p + rows]], len(ids), p // rows + 1


def _db(tmp_path):
    from app.database import init_db

    eng = create_engine(f"sqlite:///{tmp_path/'c.db'}", connect_args={"check_same_thread": False})
    init_db(eng)
    return sessionmaker(bind=eng)()


def test_paged_collect_and_stale(tmp_path):
    db = _db(tmp_path)
    src = PagedSource(list(range(0, 25)), list(range(100, 130)))
    r = collector.collect_notices(db, sources=[src], num_of_rows=10, embed_images=False)
    info = r["sources"][0]
    assert r["fetched"] == 55 and info["complete"] and info["totals"] == {"notice": 25, "protect": 30}
    assert len(matchable_notices(db)) == 55

    src2 = PagedSource(list(range(5, 25)), list(range(100, 130)))
    r2 = collector.collect_notices(db, sources=[src2], num_of_rows=10, embed_images=False)
    assert r2["sources"][0]["marked_stale"] == 5
    ids = {n.notice_id for n in matchable_notices(db)}
    assert len(ids) == 50 and "N0" not in ids
    assert db.get(NoticeRow, "N0").process_state == STALE_STATE

    collector.collect_notices(db, sources=[src], num_of_rows=10, embed_images=False)
    assert len(matchable_notices(db)) == 55


def test_partial_failure_does_not_mark_stale(tmp_path):
    db = _db(tmp_path)
    collector.collect_notices(db, sources=[PagedSource(list(range(25)), [])], num_of_rows=10, embed_images=False)
    r = collector.collect_notices(
        db, sources=[PagedSource(list(range(25)), [], fail_after=1)], num_of_rows=10, embed_images=False
    )
    info = r["sources"][0]
    assert not info["complete"] and "marked_stale" not in info
    assert len(matchable_notices(db)) == 25


def test_embed_pending_limit(tmp_path, monkeypatch):
    from pathlib import Path

    db = _db(tmp_path)
    photo = str(Path(__file__).resolve().parents[2] / "web" / "assets" / "dogs" / "mix_black.jpg")
    for i in range(5):
        r = _rec(i, "notice")
        r.photo_url = photo
        collector.upsert_record(db, r)
    db.commit()
    s = embed_pending(db, limit=3, chunk=2)
    assert s["embedded"] == 3 and s["remaining"] == 2
    s = embed_pending(db, limit=10, chunk=2)
    assert s["embedded"] == 2 and s["remaining"] == 0
