from functools import lru_cache
from urllib.parse import unquote

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

# GitHub Pages 웹과 로컬 개발 기본 허용 origin
DEFAULT_CORS_ORIGINS = (
    "https://rlawogus0703.github.io,"
    "http://localhost,"
    "http://127.0.0.1"
)
# 로컬 Flutter/크롬은 포트가 매번 달라질 수 있음
LOCAL_ORIGIN_REGEX = r"https://rlawogus0703\.github\.io|https?://(localhost|127\.0\.0\.1)(:\d+)?"


def normalize_database_url(url: str) -> str:
    """postgres:// 와 postgresql:// 를 SQLAlchemy+psycopg3 형식으로 바꾸고,
    스키마가 빠진 Neon 연결 문자열(user:pass@host/db)도 받습니다.
    """
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
    """로그·에러 메시지에서 DB URL 비밀번호와 인증키를 가립니다."""
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
    # 공공데이터포털 일반 인증키 (Decoding 키 권장, Encoding 키를 넣어도 자동 변환)
    service_key: str | None = Field(
        default=None, validation_alias=AliasChoices("SERVICE_KEY", "DATA_GO_KR_SERVICE_KEY")
    )
    public_api_base: str = "https://apis.data.go.kr/1543061/abandonmentPublicService_v2"
    collect_interval_minutes: int = 60
    collect_pages: int = 20  # 상태별 최대 페이지 수 (안전장치, 1000건 × 20)
    collect_rows: int = 1000  # 페이지당 공고 수 (최대 1000)
    # 공고중(notice) 전부 + 공고가 끝났지만 아직 보호 중(protect)인 최근 N일 공고
    collect_states: str = "notice,protect"
    collect_protect_days: int = 90
    # 사진 임베딩은 한 번에 다 하지 않고 수집 1회마다 조금씩 (무료 서버 메모리·시간 보호)
    embed_batch_per_run: int = 3000
    embed_chunk: int = 100
    embed_time_budget_seconds: int = 1200
    # 목록에서 빠진(입양·반환 등) 공고는 매칭에서 빼고, 오래되면 DB 에서 정리
    stale_delete_days: int = 30
    collect_on_startup: bool = True  # 키가 있으면 서버 시작 때 1회 수집
    embed_images_on_collect: bool = True  # 수집하면서 공고 사진 임베딩까지 계산
    image_fetch_timeout: float = 8.0
    image_workers: int = 8
    match_store_top: int = 200  # 실종견 1마리당 저장할 매칭 결과 수
    match_image_top_k: int = 40  # 매칭 때 사진 임베딩이 없으면 상위 K개만 즉석 계산
    enable_scheduler: bool = True
    cors_origins: str = DEFAULT_CORS_ORIGINS

    @property
    def collect_state_list(self) -> list[str]:
        return [x.strip() for x in self.collect_states.split(",") if x.strip()]

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
