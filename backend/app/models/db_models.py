import json
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base



class UserRow(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(256), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(256))
    name: Mapped[str] = mapped_column(String(128), default="")
    phone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime)


class LostDogRow(Base):
    __tablename__ = "lost_dogs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    breed: Mapped[str] = mapped_column(String(128))
    color: Mapped[str] = mapped_column(String(64))
    features: Mapped[str] = mapped_column(Text, default="")
    age: Mapped[str | None] = mapped_column(String(64), nullable=True)
    lost_date: Mapped[date] = mapped_column(Date)
    lost_lat: Mapped[float] = mapped_column(Float)
    lost_lng: Mapped[float] = mapped_column(Float)
    lost_address: Mapped[str] = mapped_column(String(256), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime)
    text_embedding_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_embedding_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_embed_method: Mapped[str | None] = mapped_column(String(32), nullable=True)
    photo_path: Mapped[str | None] = mapped_column(String(512), nullable=True)


class NoticeRow(Base):
    __tablename__ = "notices"

    notice_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    notice_no: Mapped[str] = mapped_column(String(128), default="")
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    breed: Mapped[str] = mapped_column(String(128), default="")
    color: Mapped[str] = mapped_column(String(64), default="")
    age: Mapped[str | None] = mapped_column(String(64), nullable=True)
    features: Mapped[str] = mapped_column(Text, default="")
    found_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    found_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    found_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    found_address: Mapped[str] = mapped_column(String(256), default="")
    shelter_name: Mapped[str] = mapped_column(String(128), default="")
    shelter_phone: Mapped[str] = mapped_column(String(64), default="")
    notice_url: Mapped[str] = mapped_column(String(512), default="")
    # 정규화·텍스트/이미지 특징 분리
    breed_norm: Mapped[str | None] = mapped_column(String(64), nullable=True)
    color_norm: Mapped[str | None] = mapped_column(String(64), nullable=True)
    text_embedding_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_embedding_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    raw_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # 공공 API 상세 필드 (v2)
    source: Mapped[str] = mapped_column(String(32), default="seed")
    photo_url2: Mapped[str | None] = mapped_column(String(512), nullable=True)
    photo_local: Mapped[str | None] = mapped_column(String(512), nullable=True)
    kind_full: Mapped[str] = mapped_column(String(128), default="")
    sex: Mapped[str] = mapped_column(String(8), default="")
    neuter: Mapped[str] = mapped_column(String(8), default="")
    weight: Mapped[str] = mapped_column(String(32), default="")
    care_addr: Mapped[str] = mapped_column(String(256), default="")
    org_nm: Mapped[str] = mapped_column(String(128), default="")
    process_state: Mapped[str] = mapped_column(String(32), default="")
    notice_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    notice_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    geo_level: Mapped[str] = mapped_column(String(128), default="")
    image_embed_method: Mapped[str | None] = mapped_column(String(32), nullable=True)
    image_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    collected_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class MatchResultRow(Base):
    __tablename__ = "match_results"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    lost_dog_id: Mapped[str] = mapped_column(String(36), index=True)
    notice_id: Mapped[str] = mapped_column(String(64), index=True)
    score_breed: Mapped[float] = mapped_column(Float, default=0)
    score_color: Mapped[float] = mapped_column(Float, default=0)
    score_distance: Mapped[float] = mapped_column(Float, default=0)
    score_date: Mapped[float] = mapped_column(Float, default=0)
    score_features: Mapped[float] = mapped_column(Float, default=0)
    score_age: Mapped[float] = mapped_column(Float, default=0)
    score_image: Mapped[float | None] = mapped_column(Float, nullable=True)
    score_text: Mapped[float | None] = mapped_column(Float, nullable=True)
    score_total: Mapped[float] = mapped_column(Float, default=0)
    score_rule: Mapped[float | None] = mapped_column(Float, nullable=True)
    detail_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    reasons_json: Mapped[str] = mapped_column(Text, default="[]")
    created_at: Mapped[datetime] = mapped_column(DateTime)

    def reasons(self) -> list[str]:
        try:
            return json.loads(self.reasons_json)
        except Exception:
            return []

    def detail(self) -> dict:
        try:
            return json.loads(self.detail_json or "{}")
        except Exception:
            return {}


class NotificationRow(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    lost_dog_id: Mapped[str] = mapped_column(String(36), index=True)
    notice_id: Mapped[str] = mapped_column(String(64))
    title: Mapped[str] = mapped_column(String(256))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime)
    read: Mapped[bool] = mapped_column(Boolean, default=False)
