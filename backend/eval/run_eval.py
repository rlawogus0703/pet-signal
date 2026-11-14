"""펫 시그널 Top-K 성능평가 (오프라인, 운영 DB·계정 사용 안 함).

    cd backend
    pip install -r eval/requirements.txt      # matplotlib, numpy (평가 전용)
    python -m eval.run_eval                    # 저장된 공고 스냅샷으로 평가
    python -m eval.run_eval --refresh-pool     # 공공 API 에서 공고를 새로 받아 평가 (DATA_GO_KR_SERVICE_KEY 필요)

비교하는 방법
  baseline_strict : 기존 조건 검색 — 품종 글자 일치 + 색 글자 포함 + 시·군·구 일치 + 기간, 최신순 정렬
  baseline_breed  : 관대한 기존 검색 — 품종을 드롭다운처럼 정규화해서 비교(믹스=믹스견, 진도=진도견) + 시·군·구 + 기간, 색 조건 없음, 최신순
  baseline_region : 지역 둘러보기 — 시·군·구 + 기간만 걸고 최신순 (보호자가 우리 동네 공고를 전부 넘겨보는 경우)
  rule            : 펫 시그널 규칙 점수만 (품종·색 정규화, 거리, 날짜, 나이)
  rule_text       : 규칙 + 텍스트 (0.45 : 0.25 로 다시 나눔)
  full            : 규칙 0.45 + 텍스트 0.25 + 사진 0.30 (Render 와 같은 경량 color-hist+dhash)
점수 계산은 서비스 코드(app.services.matcher.score_pair, app.ai.fusion)를 그대로 불러 씁니다.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import math
import random
import sys
import time
from dataclasses import asdict
from datetime import date, timedelta
from multiprocessing import Pool
from pathlib import Path

import numpy as np

from app.ai import image_embedder
from app.ai.fusion import MISSING_IMAGE_NEUTRAL, MODAL_WEIGHTS
from app.services.matcher import score_pair
from app.services.normalizer import norm_breed
from eval import images
from eval.fetch_pool import POOL_PATH
from eval.synth import LEVELS, SEED, Query, build_queries, degrade, notice_region

HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
KS = (1, 5, 10)
BASELINE_DAYS = 30  # 기존 검색: 실종일부터 30일 동안 올라온 공고
METHODS = ["baseline_strict", "baseline_breed", "baseline_region", "rule", "rule_text", "full"]
METHOD_KO = {
    "baseline_strict": "기존 조건 검색 (품종+색+지역+기간)",
    "baseline_breed": "관대한 기존 검색 (정규화 품종+지역+기간)",
    "baseline_region": "지역 둘러보기 (지역+기간, 최신순)",
    "rule": "펫 시그널: 규칙만",
    "rule_text": "펫 시그널: 규칙+텍스트",
    "full": "펫 시그널: 규칙+텍스트+사진 (전체)",
}
LIGHT = image_embedder.METHOD_LIGHT

# 작업 프로세스가 공유하는 전역 (fork)
_POOL: list[dict] = []
_FEATS: dict = {}


def _d(s):
    return date.fromisoformat(s) if s else None


def score_query(args) -> tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    qd, q_img = args
    q = Query(**qd)
    n_c = len(_POOL)
    rule = np.zeros(n_c)
    text = np.zeros(n_c)
    img = np.full(n_c, np.nan)
    max_err = 0.0
    for j, n in enumerate(_POOL):
        n_img = _FEATS.get(n["notice_id"]) if q_img is not None else None
        ms = score_pair(
            dog_breed=q.breed, dog_color=q.color, dog_features=q.features, dog_age=q.age,
            dog_date=q.lost_date, dog_lat=q.lat, dog_lng=q.lng, dog_text_emb=None, dog_image_emb=q_img,
            notice_breed=n["breed"], notice_color=n["color"], notice_features=n["features"] or "",
            notice_age=n["age"], notice_date=n["_fd"], notice_lat=n["found_lat"], notice_lng=n["found_lng"],
            notice_text_emb=None, notice_image_emb=n_img, notice_weight=n["weight"], image_method=LIGHT,
        )
        rule[j], text[j] = ms.rule, ms.text
        if ms.image is not None:
            img[j] = ms.image
        if j % 97 == 0:  # 아래 numpy 융합이 서비스 total 과 같은지 표본 검사
            mine = fuse(rule[j : j + 1], text[j : j + 1], img[j : j + 1], q_img is not None)[0]
            max_err = max(max_err, abs(mine - ms.total))
    return rule, text, img, max_err


def fuse(rule, text, img, has_photo: bool, w: dict | None = None) -> np.ndarray:
    """app.ai.fusion.final_score 와 같은 계산 (가중치만 바꿔 볼 수 있게 numpy 로)."""
    w = w or MODAL_WEIGHTS
    if not has_photo or w["image"] == 0:
        den = w["rule"] + w["text"]
        return np.clip((w["rule"] * rule + w["text"] * text) / den, 0, 1)
    i = np.where(np.isnan(img), MISSING_IMAGE_NEUTRAL, img)
    den = w["rule"] + w["text"] + w["image"]
    return np.clip((w["rule"] * rule + w["text"] * text + w["image"] * i) / den, 0, 1)


def rank_of(scores: np.ndarray, t: int) -> int:
    """정답 순위 (동점은 정답에 불리하게: 같은 점수인 다른 공고를 모두 앞에 둠)."""
    return int(1 + np.sum(scores >= scores[t]) - 1)


def baseline_ranks(q: Query, pool: list[dict], t: int) -> dict[str, tuple[float, int]]:
    """(정답 순위 또는 inf, 결과 목록 길이)."""
    end = q.lost_date + timedelta(days=BASELINE_DAYS)
    breed_key = q.breed.replace(" ", "")
    color_key = q.color.split()[0] if q.color.split() else ""
    unknown_breed = breed_key in ("", "모름")
    q_breed_norm = norm_breed(q.breed)
    out = {}
    for name in ("baseline_strict", "baseline_breed", "baseline_region"):
        hits = []
        for j, n in enumerate(pool):
            fd = n["_fd"]
            if fd is None or not (q.lost_date <= fd <= end):
                continue
            sido, sgg = n["_region"]
            if sido != q.region[0] or (sgg and sgg != q.region[1]):
                continue
            if name == "baseline_strict":
                if not unknown_breed and n["breed"].replace(" ", "") != breed_key:
                    continue
                if color_key and color_key not in n["color"]:
                    continue
            elif name == "baseline_breed":
                if not unknown_breed and norm_breed(n["breed"]) != q_breed_norm:
                    continue
            hits.append(j)
        hits.sort(key=lambda j: (pool[j]["_fd"], pool[j]["notice_id"]), reverse=True)  # 최신순
        r = math.inf
        if t in hits:
            r = hits.index(t) + 1
        out[name] = (r, len(hits))
    return out


def metrics(ranks: list[float]) -> dict:
    r = np.array(ranks, dtype=float)
    found = r[np.isfinite(r)]
    m = {f"top{k}": float(np.mean(r <= k)) for k in KS}
    m["mrr"] = float(np.mean(np.where(np.isfinite(r), 1.0 / r, 0.0)))
    m["missed"] = float(np.mean(~np.isfinite(r)))
    m["mean_rank_found"] = float(found.mean()) if len(found) else None
    m["median_rank"] = float(np.median(r)) if np.isfinite(np.median(r)) else None
    m["n"] = int(len(r))
    return m


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--refresh-pool", action="store_true")
    ap.add_argument("--per-level", type=int, default=60)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--cached-images-only", action="store_true", help="새 공고 사진은 받지 않고 캐시된 특징만 사용")
    a = ap.parse_args(argv)
    global _POOL, _FEATS

    if a.refresh_pool or not POOL_PATH.is_file():
        from eval import fetch_pool

        if fetch_pool.main() != 0:
            return 1
    snap = json.load(gzip.open(POOL_PATH, "rt", encoding="utf-8"))
    pool = snap["notices"]
    for n in pool:
        n["_fd"] = _d(n["found_date"])
        n["_region"] = notice_region(n)
    idx = {n["notice_id"]: i for i, n in enumerate(pool)}
    print(f"후보 공고 {len(pool)}건 (스냅샷 {snap['fetched_at']})")

    queries = build_queries(pool, per_level=a.per_level, seed=a.seed)
    print(f"가상 실종 신고 {len(queries)}건 생성")
    print("후보 공고 사진 특징 계산 (처음 한 번만 오래 걸림) …")
    if a.cached_images_only:
        feats = images.load_feats()
    else:
        feats = images.build_notice_feats(pool, keep_bytes_for={q.true_id for q in queries})
    _POOL, _FEATS = pool, feats

    # 질의 사진 만들기
    q_imgs: list = []
    for q in queries:
        emb = None
        if q.photo_url:
            raw = images.photo_bytes(q.photo_url)
            if raw:
                data = degrade(raw, q.photo_kind, random.Random(f"{a.seed}-{q.qid}-img"))
                emb = image_embedder.light_features_from_bytes(data) if data else None
            if emb is None:
                q.photo_kind = "none(fetch_failed)"
        q_imgs.append(emb)

    t0 = time.time()
    with Pool(a.workers) as p:
        parts = p.map(score_query, [(asdict(q), e) for q, e in zip(queries, q_imgs)], chunksize=2)
    print(f"점수 계산 {time.time() - t0:.0f}초")
    max_err = max(x[3] for x in parts)
    assert max_err < 1e-9, f"numpy 융합이 서비스 total 과 다릅니다 ({max_err})"

    rows = []
    per_q: dict[str, list] = {m: [] for m in METHODS}
    comp = []
    for q, e, (rule, text, img, _) in zip(queries, q_imgs, parts):
        t = idx[q.true_id]
        b = baseline_ranks(q, pool, t)
        has = e is not None
        r = {
            "baseline_strict": b["baseline_strict"][0],
            "baseline_breed": b["baseline_breed"][0],
            "baseline_region": b["baseline_region"][0],
            "rule": rank_of(rule, t),
            "rule_text": rank_of(fuse(rule, text, img, False), t),
            "full": rank_of(fuse(rule, text, img, has), t),
        }
        for m in METHODS:
            per_q[m].append(r[m])
        comp.append((rule, text, img, has, t, q.level))
        rows.append({
            "qid": q.qid, "level": q.level, "true_notice": q.true_id,
            "notice_breed": pool[t]["breed"], "notice_color": pool[t]["color"],
            "owner_breed": q.breed, "owner_color": q.color, "owner_age": q.age or "",
            "owner_features": q.features, "shift_km": round(q.shift_km, 2), "day_gap": q.day_gap,
            "owner_region": " ".join(q.region), "notice_region": " ".join(pool[t]["_region"]),
            "photo": q.photo_kind, "tags": " ".join(q.tags),
            **{f"rank_{m}": ("" if math.isinf(r[m]) else int(r[m])) for m in METHODS},
            "baseline_strict_list_len": b["baseline_strict"][1],
            "baseline_breed_list_len": b["baseline_breed"][1],
            "baseline_region_list_len": b["baseline_region"][1],
            "image_score_true": "" if np.isnan(img[t]) else round(float(img[t]), 3),
        })

    # 요약
    summary = {"overall": {}, "by_level": {lv: {} for lv in LEVELS}, "photo_queries": {}}
    levels = [q.level for q in queries]
    has_photo = [e is not None for e in q_imgs]
    for m in METHODS:
        summary["overall"][m] = metrics(per_q[m])
        for lv in LEVELS:
            summary["by_level"][lv][m] = metrics([x for x, l in zip(per_q[m], levels) if l == lv])
        summary["photo_queries"][m] = metrics([x for x, h in zip(per_q[m], has_photo) if h])
    summary["baseline_list_len_mean"] = {
        k: float(np.mean([r[f"{k}_list_len"] for r in rows])) for k in ("baseline_strict", "baseline_breed", "baseline_region")
    }

    # 가중치 민감도 (규칙 : 텍스트 : 사진)
    grid = [
        (0.45, 0.25, 0.30), (0.60, 0.20, 0.20), (0.34, 0.33, 0.33), (0.30, 0.20, 0.50),
        (0.50, 0.50, 0.00), (0.70, 0.30, 0.00), (0.55, 0.15, 0.30), (0.40, 0.40, 0.20),
    ]
    sens = []
    for wr, wt, wi in grid:
        w = {"rule": wr, "text": wt, "image": wi}
        rk = [rank_of(fuse(ru, te, im, h, w), t) for ru, te, im, h, t, _ in comp]
        mm = metrics(rk)
        sens.append({"rule": wr, "text": wt, "image": wi, **{k: mm[k] for k in ("top1", "top5", "top10", "mrr")}})

    # 누적 Top-K 곡선
    curve = {}
    for m in METHODS:
        rr = np.array(per_q[m], dtype=float)
        curve[m] = [float(np.mean(rr <= k)) for k in range(1, 51)]

    RESULTS.mkdir(parents=True, exist_ok=True)
    meta = {
        "pool_size": len(pool), "pool_fetched_at": snap["fetched_at"], "pool_totals": snap["totals"],
        "queries": len(queries), "per_level": a.per_level, "seed": a.seed,
        "queries_with_photo": int(sum(has_photo)),
        "notice_photo_features": int(sum(1 for n in pool if feats.get(n["notice_id"]))),
        "image_method": LIGHT, "text_semantic_method": "char-ngram (sentence-transformers 미설치, Render 와 같음)",
        "modal_weights": MODAL_WEIGHTS, "baseline_days": BASELINE_DAYS, "tie_rule": "동점은 정답에 불리하게",
    }
    (RESULTS / "summary.json").write_text(
        json.dumps({"meta": meta, **summary, "weight_sensitivity": sens, "topk_curve": curve}, ensure_ascii=False, indent=1)
    )
    with open(RESULTS / "per_query.csv", "w", newline="", encoding="utf-8-sig") as f:
        wr_ = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        wr_.writeheader()
        wr_.writerows(rows)
    with open(RESULTS / "summary.csv", "w", newline="", encoding="utf-8-sig") as f:
        w_ = csv.writer(f)
        w_.writerow(["subset", "method", "n", "top1", "top5", "top10", "mrr", "missed", "mean_rank_found", "median_rank"])
        for sub, block in [("overall", summary["overall"]), ("photo_queries", summary["photo_queries"])] + [
            (lv, summary["by_level"][lv]) for lv in LEVELS
        ]:
            for m in METHODS:
                x = block[m]
                w_.writerow([sub, m, x["n"], *(round(x[k], 4) for k in ("top1", "top5", "top10", "mrr", "missed")),
                             "" if x["mean_rank_found"] is None else round(x["mean_rank_found"], 1),
                             "" if x["median_rank"] is None else x["median_rank"]])
    with open(RESULTS / "weight_sensitivity.csv", "w", newline="", encoding="utf-8") as f:
        w_ = csv.DictWriter(f, fieldnames=list(sens[0].keys()))
        w_.writeheader()
        w_.writerows(sens)

    from eval.charts import draw

    draw(summary, curve, RESULTS)
    print_table(summary)
    print(f"결과: {RESULTS}")
    return 0


def print_table(summary):
    print(f"{'method':18s} {'Top1':>6s} {'Top5':>6s} {'Top10':>6s} {'MRR':>6s} {'missed':>7s}")
    for m in METHODS:
        x = summary["overall"][m]
        print(f"{m:18s} {x['top1']:6.3f} {x['top5']:6.3f} {x['top10']:6.3f} {x['mrr']:6.3f} {x['missed']:7.3f}")


if __name__ == "__main__":
    sys.exit(main())
