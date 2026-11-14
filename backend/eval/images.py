"""평가용 사진 특징 캐시 (경량 color-hist+dhash, 서비스 Render 와 같은 방식).

- 후보 공고: 서비스와 같은 순서(popfile1 → popfile2)로 받은 사진의 128차원 특징을
  eval/cache/notice_light_feats.json 에 저장합니다 (다시 받지 않음, git 에는 올리지 않음).
- 질의(가상 보호자) 사진: 원본 바이트를 eval/cache/img/ 에 저장해 두고 변형해서 씁니다.
"""

from __future__ import annotations

import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

from app.ai import image_embedder

CACHE_DIR = Path(__file__).resolve().parent / "cache"
FEATS_PATH = CACHE_DIR / "notice_light_feats.json"
IMG_DIR = CACHE_DIR / "img"


def _fetch(url: str | None, client: httpx.Client) -> bytes | None:
    if not url:
        return None
    p = IMG_DIR / (hashlib.sha1(url.encode()).hexdigest() + ".img")
    if p.is_file() and p.stat().st_size > 0:
        return p.read_bytes()
    data = image_embedder.fetch_bytes(url, timeout=15.0, client=client, cache=False)
    if data:
        IMG_DIR.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    return data


def photo_bytes(url: str | None, client: httpx.Client | None = None) -> bytes | None:
    own = client is None
    client = client or httpx.Client()
    try:
        return _fetch(url, client)
    finally:
        if own:
            client.close()


def load_feats() -> dict[str, list[float] | None]:
    if FEATS_PATH.is_file():
        return json.loads(FEATS_PATH.read_text())
    return {}


def build_notice_feats(notices: list[dict], keep_bytes_for: set[str] | None = None, workers: int = 16) -> dict:
    """후보 공고 사진 특징 계산 (이미 있는 것은 건너뜀). 실패하면 None."""
    feats = load_feats()
    keep_bytes_for = keep_bytes_for or set()
    todo = [n for n in notices if n["notice_id"] not in feats]
    if not todo:
        return feats
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def work(n: dict):
        with httpx.Client() as client:
            for u in (n.get("photo_url"), n.get("photo_url2")):
                if not u:
                    continue
                if n["notice_id"] in keep_bytes_for:
                    data = _fetch(u, client)
                else:
                    data = image_embedder.fetch_bytes(u, timeout=15.0, client=client, cache=False)
                if data:
                    f = image_embedder.light_features_from_bytes(data)
                    if f:
                        return n["notice_id"], [round(x, 6) for x in f]
        return n["notice_id"], None

    done = 0
    with ThreadPoolExecutor(max_workers=workers) as ex:
        for nid, f in ex.map(work, todo):
            feats[nid] = f
            done += 1
            if done % 500 == 0:
                print(f"  사진 특징 {done}/{len(todo)}", flush=True)
                FEATS_PATH.write_text(json.dumps(feats))
    FEATS_PATH.write_text(json.dumps(feats))
    return feats


if __name__ == "__main__":
    import gzip

    from eval.fetch_pool import POOL_PATH

    pool = json.load(gzip.open(POOL_PATH, "rt", encoding="utf-8"))["notices"]
    f = build_notice_feats(pool)
    print("ok", sum(1 for v in f.values() if v), "/", len(f))
