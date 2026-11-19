from functools import lru_cache
from urllib.parse import unquote

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_CORS_ORIGINS = (
    "https://rlawogus0703.github.io,"
    "http://localhost,"
    "http://127.0.0.1"
)
LOCAL_ORIGIN_REGEX = r"https://rlawogus0703\.github\.io|https?://(localhost|127\.0\.0\.1)(:\d+)?"


def normalize_database_url(url: str) -> str:
    raw = (url or "").strip()
    if not raw:
        return "sqlite:///./petsignal.db"
    if "://" not in raw:
        raw = "postgresql://" + raw
    if raw.startswith("postgres://"):
        raw = "postgresql://" + raw[len("postgres://") :]
    if raw.startswith("postgresql://"):
        raw = "postgresql+psycopg://" + raw[len("postgresql://") :]
    return raw


def redact_secrets(text: str, *extra: str | None) -> str:
    import re

    s = text or ""
    s = re.sub(r"(://)([^:/@\s]+):([^@\s]+)@", r"\1***:***@", s)
    s = re.sub(r"(postgresql\+psycopg://)([^:/@\s]+):([^@\s]+)@", r"\1***:***@", s)
    for secret in extra:
        if secret and len(secret) >= 8:
            s = s.replace(secret, "***")
    return s


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "sqlite:///./petsignal.db"
    service_key: str | None = Field(
        default=None, validation_alias=AliasChoices("SERVICE_KEY", "DATA_GO_KR_SERVICE_KEY")
    )
    public_api_base: str = "https://apis.data.go.kr/1543061/abandonmentPublicService_v2"
    collect_interval_minutes: int = 60
    collect_pages: int = 20
    collect_rows: int = 1000
    collect_states: str = "notice,protect"
    collect_protect_days: int = 90
    collect_upkinds: str = "417000,422400"
    embed_batch_per_run: int = 3000
    embed_chunk: int = 100
    embed_time_budget_seconds: int = 1200
    stale_delete_days: int = 30
    collect_on_startup: bool = True
    embed_images_on_collect: bool = True
    image_fetch_timeout: float = 8.0
    image_workers: int = 8
    match_store_top: int = 200
    match_image_top_k: int = 40
    enable_scheduler: bool = True
    admin_api_key: str | None = None
    cors_origins: str = DEFAULT_CORS_ORIGINS

    @property
    def collect_state_list(self) -> list[str]:
        return [x.strip() for x in self.collect_states.split(",") if x.strip()]

    @property
    def collect_upkind_list(self) -> list[str]:
        return [x.strip() for x in self.collect_upkinds.split(",") if x.strip()]

    @property
    def sqlalchemy_database_url(self) -> str:
        return normalize_database_url(self.database_url)

    @property
    def is_sqlite(self) -> bool:
        return self.sqlalchemy_database_url.startswith("sqlite")

    @property
    def decoded_service_key(self) -> str | None:
        k = (self.service_key or "").strip()
        if not k or not k.isascii() or k.lower() in {"your_key_here", "changeme"}:
            return None
        return unquote(k) if "%" in k else k


@lru_cache
def get_settings() -> Settings:
    return Settings()
