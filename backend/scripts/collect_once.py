"""공공 API 1회 수집 (키 확인용): python -m scripts.collect_once --rows 20

backend/.env 의 SERVICE_KEY 를 사용합니다. 수집 후 사진 임베딩까지 계산하고 요약을 출력합니다.
"""

import argparse
import json
import logging

from app.ai import image_embedder, text_similarity
from app.console import make_console_safe
from app.database import SessionLocal, init_db
from app.services.collector import collect_notices


def main() -> None:
    make_console_safe()
    logging.getLogger("httpx").setLevel(logging.WARNING)  # URL 에 인증키가 있어 숨김
    ap = argparse.ArgumentParser()
    ap.add_argument("--pages", type=int, default=1)
    ap.add_argument("--rows", type=int, default=20)
    ap.add_argument("--no-images", action="store_true", help="사진 임베딩 계산 생략")
    args = ap.parse_args()

    init_db()
    print(f"텍스트 의미 분석 방식: {text_similarity.semantic_method()}")
    print(f"이미지 임베딩 방식: {image_embedder.current_method()}")
    db = SessionLocal()
    try:
        res = collect_notices(db, pages=args.pages, num_of_rows=args.rows, embed_images=not args.no_images)
    finally:
        db.close()
    print(json.dumps(res, ensure_ascii=False, indent=2))
    if not res.get("ok"):
        print("\n수집 실패: backend/.env 의 SERVICE_KEY 를 확인해 주세요 (Decoding 키 권장).")


if __name__ == "__main__":
    main()
