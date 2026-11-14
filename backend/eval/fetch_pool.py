"""평가용 후보 공고 풀(스냅샷) 만들기.

서비스와 같은 조건(공고중 전부 + 보호중 최근 90일, 개만)으로 공공데이터포털
abandonmentPublic_v2 를 직접 불러 backend/eval/data/pool.json.gz 에 저장합니다.
운영 DB 에는 아무것도 쓰지 않습니다. 인증키(DATA_GO_KR_SERVICE_KEY)는 파일에 남기지 않습니다.

    cd backend && python -m eval.fetch_pool
"""

from __future__ import annotations

import gzip
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.sources.animal_api import AnimalProtectionSource

DATA_DIR = Path(__file__).resolve().parent / "data"
POOL_PATH = DATA_DIR / "pool.json.gz"
KEEP = [
    "notice_id", "breed", "kind_full", "color", "age", "weight", "sex", "features",
    "found_date", "found_address", "found_lat", "found_lng", "geo_level",
    "photo_url", "photo_url2", "org_nm", "process_state", "notice_start", "notice_end",
]


def main() -> int:
    src = AnimalProtectionSource()
    if not src.enabled():
        print("DATA_GO_KR_SERVICE_KEY 가 없습니다.", file=sys.stderr)
        return 1
    seen: dict[str, dict] = {}
    totals: dict[str, int] = {}
    for state, recs, total, page in src.iter_pages(rows=1000, max_pages=20):
        totals[state] = total
        for r in recs:
            d = {k: getattr(r, k) for k in KEEP}
            for k in ("found_date", "notice_start", "notice_end"):
                d[k] = d[k].isoformat() if d[k] else None
            seen.setdefault(r.notice_id, d)
        print(f"{state} page {page}: {len(recs)} (total {total})")
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    snap = {
        "fetched_at": datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds"),
        "source": "apis.data.go.kr/1543061/abandonmentPublicService_v2/abandonmentPublic_v2 (upkind=417000)",
        "totals": totals,
        "notices": sorted(seen.values(), key=lambda d: d["notice_id"]),
    }
    with gzip.open(POOL_PATH, "wt", encoding="utf-8") as f:
        json.dump(snap, f, ensure_ascii=False)
    print(f"saved {len(seen)} notices → {POOL_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
