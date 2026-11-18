from collections.abc import Generator
import logging

from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings, redact_secrets

log = logging.getLogger("petsignal")

settings = get_settings()
_url = settings.sqlalchemy_database_url
_engine_kwargs: dict = {"pool_pre_ping": True}
if settings.is_sqlite:
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    _engine_kwargs.update(
        pool_size=5,
        max_overflow=5,
        pool_recycle=300,
        connect_args={"connect_timeout": 30},
    )

engine = create_engine(_url, **_engine_kwargs)
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
    try:
        Base.metadata.create_all(bind=eng)
        _add_missing_columns(eng)
    except Exception as exc:
        key = get_settings().decoded_service_key
        raise type(exc)(redact_secrets(str(exc), key)) from None


def _add_missing_columns(eng) -> None:
    from sqlalchemy import inspect

    insp = inspect(eng)
    dialect = eng.dialect.name
    with eng.begin() as conn:
        for table in Base.metadata.sorted_tables:
            if not insp.has_table(table.name):
                continue
            have = {c["name"] for c in insp.get_columns(table.name)}
            for col in table.columns:
                if col.name in have:
                    continue
                ddl_type = col.type.compile(dialect=eng.dialect)
                if dialect == "postgresql":
                    conn.execute(
                        text(f'ALTER TABLE "{table.name}" ADD COLUMN IF NOT EXISTS "{col.name}" {ddl_type}')
                    )
                else:
                    conn.execute(text(f"ALTER TABLE {table.name} ADD COLUMN {col.name} {ddl_type}"))
