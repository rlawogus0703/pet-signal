"""예시 공고 시드 스크립트: python -m scripts.seed_data"""

from app.console import make_console_safe
from app.database import SessionLocal, init_db
from app.services.seed import seed_notices


def main() -> None:
    make_console_safe()
    init_db()
    db = SessionLocal()
    try:
        n = seed_notices(db)
        print(f"seeded/updated notices, new inserts={n}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
