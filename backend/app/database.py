from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings

settings = get_settings()
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db(bind=None) -> None:
    from app.models import db_models  # noqa: F401

    eng = bind or engine
    Base.metadata.create_all(bind=eng)
    _add_missing_columns(eng)


def _add_missing_columns(eng) -> None:
    """예전 버전 DB(petsignal.db)에 새 컬럼을 자동 추가 (간단 마이그레이션)."""
    from sqlalchemy import inspect, text

    insp = inspect(eng)
    with eng.begin() as conn:
        for table in Base.metadata.sorted_tables:
            if not insp.has_table(table.name):
                continue
            have = {c["name"] for c in insp.get_columns(table.name)}
            for col in table.columns:
                if col.name in have:
                    continue
                ddl_type = col.type.compile(dialect=eng.dialect)
                conn.execute(text(f'ALTER TABLE {table.name} ADD COLUMN {col.name} {ddl_type}'))
