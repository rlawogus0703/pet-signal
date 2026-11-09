from datetime import date, datetime

from pydantic import BaseModel, Field


class LostDogCreate(BaseModel):
    photo_url: str | None = None
    breed: str
    color: str
    features: str = ""
    age: str | None = None
    lost_date: date
    lost_lat: float
    lost_lng: float
    lost_address: str = ""


class LostDogOut(BaseModel):
    id: str
    user_id: str | None = None
    photo_url: str | None = None
    breed: str
    color: str
    features: str = ""
    age: str | None = None
    lost_date: date
    lost_lat: float
    lost_lng: float
    lost_address: str = ""
    created_at: datetime


class ScoreBreakdown(BaseModel):
    breed: float = 0
    color: float = 0
    distance: float = 0
    date: float = 0
    features: float = 0
    age: float = 0
    image: float | None = None
    text: float | None = None
    total: float = 0


class CandidateOut(BaseModel):
    notice_id: str
    notice_no: str = ""
    photo_url: str | None = None
    breed: str = ""
    color: str = ""
    age: str | None = None
    features: str = ""
    found_date: date | None = None
    found_lat: float | None = None
    found_lng: float | None = None
    found_address: str = ""
    shelter_name: str = ""
    shelter_phone: str = ""
    notice_url: str = ""
    score: ScoreBreakdown
    reasons: list[str] = Field(default_factory=list)
    rank: int = 0


class CandidateListOut(BaseModel):
    lost_dog_id: str
    disclaimer: str = (
        "결과는 유사 후보이며 동일 개체로 단정하지 않습니다. "
        "공고 원문과 사진을 직접 확인해 주세요."
    )
    total: int
    items: list[CandidateOut]


class NotificationOut(BaseModel):
    id: str
    lost_dog_id: str
    notice_id: str
    title: str
    body: str
    created_at: datetime
    read: bool = False


class NotificationListOut(BaseModel):
    lost_dog_id: str
    items: list[NotificationOut]



class SignupRequest(BaseModel):
    email: str
    password: str
    name: str = ""
    phone: str | None = None


class LoginRequest(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: str
    email: str
    name: str = ""
    phone: str | None = None
    created_at: datetime


class AuthTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
