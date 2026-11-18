# 펫 시그널 (Pet Signal) — REST API 설명

매칭 결과는 같은 개라고 단정하지 않고, 항상 **유사 후보**로 표시합니다.
최종 확인은 공고 원문과 사진을 본 보호자와 보호소가 합니다.

- Base URL (로컬): `http://127.0.0.1:8000`
- Content-Type: `application/json`
- 인증: JWT (회원가입/로그인). 공고 둘러보기는 인증 없이 가능합니다.

---

## 공통 타입

### LostDog (실종견)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (uuid) | 서버 발급 |
| photo_url | string \| null | 사진 URL (없으면 null) |
| breed | string | 품종 (예: 말티즈) |
| color | string | 색상 (예: 흰색) |
| features | string | 특징 문구 |
| age | string \| null | 나이/연령대 (예: `3살`, `2~3년`) |
| lost_date | string (YYYY-MM-DD) | 실종 날짜 |
| lost_lat | number | 실종 위치 위도 |
| lost_lng | number | 실종 위치 경도 |
| lost_address | string | 주소 텍스트 |
| created_at | string (ISO8601) | 등록 시각 |

### ScoreBreakdown (규칙 점수 100점 + 예전 필드)

순위 기준은 **규칙 점수 100점**입니다. 일치 근거를 합산한 점수이며 동일견일 확률이 아닙니다.

| 필드 | 설명 |
|------|------|
| points | 규칙 점수 (0~100, 예: 65) |
| max_points | 100 |
| items | `[{key, label, points, max, reason}]` 다섯 개: breed 품종 30 · color 색상 25 · region 지역 20 · features 특징 15 · date 날짜 10. 예: `{"key":"color","label":"색상","points":25,"max":25,"reason":"공통 색상: 흰색"}` |
| caption | `일치 근거를 합산한 점수이며, 동일견일 확률이 아니에요.` |
| note | `지역은 시군구 표기를 비교해요. 실제 거리와 사진 유사도는 계산하지 않아요. 구조 접수일은 실제 발견일과 다를 수 있어요.` |
| total | points / 100 (0~1) |

아래는 예전 필드입니다 (0~1). breed/color/date/features 는 받은 점수/만점, distance 칸에는 지역 점수(0 또는 1)가 들어갑니다. text/image 는 순위에 쓰지 않아 null 입니다.

| 필드 | 설명 |
|------|------|
| breed / color / distance / date / age | 규칙 항목 점수 |
| features | 특징 키워드 점수 (= text_keyword, 예전 호환) |
| rule | 규칙 점수 (품종 25·색상 25·거리 25·날짜 15·나이 10) |
| text | 텍스트 점수 = 키워드 0.4 + 문장 의미 0.4 + 속성/성향 0.2 |
| text_keyword / text_semantic / text_attribute | 텍스트 세부 (attribute 는 비교할 속성이 없으면 null) |
| text_method | `sentence-transformers` 또는 `char-ngram` |
| image | 사진 유사도 (사진이 없으면 null) |
| image_method | `clip` 또는 `color-hist+dhash` |
| image_status | `ok` · `no_user_photo` · `no_notice_photo` · `fetch_failed` |

### Candidate (유사 후보)

| 필드 | 타입 | 설명 |
|------|------|------|
| notice_id | string | 공고 식별자 (desertionNo 등) |
| notice_no | string | 공고 번호 |
| photo_url | string \| null | 공고 사진 |
| breed | string | 공고 품종 |
| color | string | 공고 색상 |
| age | string \| null | 공고 나이 |
| features | string | 특징/특이사항 |
| found_date | string (YYYY-MM-DD) | 구조/발견일 |
| found_lat / found_lng | number \| null | 구조 위치 |
| found_address | string | 구조 장소 |
| shelter_name | string | 보호소명 |
| shelter_phone | string | 보호소 전화 |
| notice_url | string | animal.go.kr 원문 링크 |
| score | ScoreBreakdown | 항목별·총점 |
| reasons | string[] | 항목별 한 줄 근거 (예: `품종 30/30점 · 일치 (포메라니안)`) |
| rank | int | 순위 (1부터) |
| rule_score / final_score | number | 규칙 점수 / 100 (text_score·image_score 는 null) |
| source | string | `seed`(예시) 또는 `animal_api`(공공 API) |
| photo_url2 | string \| null | 두 번째 공고 사진 (popfile2) |
| photo_proxy_url / photo2_proxy_url | string \| null | 서버 경유 사진 경로 (웹 CORS 회피, base URL 뒤에 붙여 사용) |
| kind_full, sex, neuter, weight, process_state, org_name | string | 공고 상세 |
| shelter_address | string | 보호소 주소 (careAddr) |
| notice_start / notice_end | string (YYYY-MM-DD) \| null | 공고 기간 |
| common_keywords / matched_attributes | string[] | 공통 특징 키워드 / 일치한 문장 속성 |
| dist_km / day_diff | number | 거리(km) / 발견일-실종일 |

### NotificationItem

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string | 알림 id |
| lost_dog_id | string | 대상 실종견 |
| notice_id | string | 신규 후보 공고 |
| title | string | 알림 제목 |
| body | string | 본문 |
| created_at | string (ISO8601) | 시각 |
| read | boolean | 읽음 여부 |

---

## 0. 인증 (회원가입 / 로그인)

### `POST /auth/signup`

```json
{
  "email": "user@example.com",
  "password": "pass1234",
  "name": "홍길동",
  "phone": "010-1111-2222"
}
```

### Response `201`

```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "user": {
    "id": "u-uuid",
    "email": "user@example.com",
    "name": "홍길동",
    "phone": "010-1111-2222",
    "created_at": "2026-11-09T13:00:00"
  }
}
```

### `POST /auth/login`

```json
{ "email": "user@example.com", "password": "pass1234" }
```

응답 형식은 signup과 동일.

### `GET /auth/me`

Header: `Authorization: Bearer <token>`

실종견 등록(`POST /api/v1/lost-dogs`) 시 Bearer 토큰이 있으면 `user_id`가 연결된다.

---

## 1. 실종견 등록

`POST /api/v1/lost-dogs`

### Request

```json
{
  "photo_url": "https://example.com/my-dog.jpg",
  "breed": "말티즈",
  "color": "흰색",
  "features": "왼쪽 귀에 작은 점, 빨간 목걸이",
  "age": "3살",
  "lost_date": "2026-10-28",
  "lost_lat": 37.5665,
  "lost_lng": 126.9780,
  "lost_address": "서울특별시 중구 명동",
  "photo_data": "<선택: 사진 base64 또는 data:image/jpeg;base64,...>"
}
```

`photo_data` 를 보내면 서버가 사진을 저장하고 이미지 임베딩을 계산해 이미지 유사도에 씁니다.
응답에 `has_photo`, `photo_proxy_url`(`/api/v1/lost-dogs/{id}/photo`), `image_method` 가 추가됩니다.

### Response `201`

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_url": "https://example.com/my-dog.jpg",
  "breed": "말티즈",
  "color": "흰색",
  "features": "왼쪽 귀에 작은 점, 빨간 목걸이",
  "age": "3살",
  "lost_date": "2026-10-28",
  "lost_lat": 37.5665,
  "lost_lng": 126.9780,
  "lost_address": "서울특별시 중구 명동",
  "created_at": "2026-11-09T13:00:00+09:00"
}
```

---

## 2. 실종견 조회

`GET /api/v1/lost-dogs/{lost_dog_id}`

### Response `200` — LostDog 객체

---

## 3. 유사 후보 목록 (점수 순)

`GET /api/v1/lost-dogs/{lost_dog_id}/candidates?limit=20`

결과는 **유사 후보**이며 동일 견 단정이 아님.

### Response `200`

```json
{
  "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "disclaimer": "결과는 유사 후보이며 동일 개체로 단정하지 않습니다. 공고 원문과 사진을 직접 확인해 주세요.",
  "total": 2,
  "items": [
    {
      "notice_id": "N20261101001",
      "notice_no": "서울-중구-2026-00123",
      "photo_url": null,
      "breed": "믹스견",
      "color": "크림색",
      "age": "2~3년",
      "features": "소형, 귀가 접힘, 목걸이 흔적",
      "found_date": "2026-10-30",
      "found_lat": 37.5700,
      "found_lng": 126.9850,
      "found_address": "서울특별시 중구 을지로",
      "shelter_name": "중구 동물보호센터",
      "shelter_phone": "02-1234-5678",
      "notice_url": "https://www.animal.go.kr/front/awtis/protection/protectionList.do",
      "score": {
        "breed": 0.6,
        "color": 0.85,
        "distance": 0.92,
        "date": 0.9,
        "features": 0.55,
        "age": 0.8,
        "image": 0.82,
        "text": 0.71,
        "total": 0.78
      },
      "reasons": [
        "색상 유사 (흰색 ↔ 크림색)",
        "품종 유사 (말티즈 ↔ 믹스견)",
        "실종 지점과 약 0.8km",
        "날짜 차이 2일",
        "나이 유사 (3살 ↔ 2~3년)",
        "사진 유사도 0.82",
        "설명 텍스트 유사도 0.71"
      ],
      "rank": 1
    }
  ]
}
```

---

## 4. 후보 상세 (항목별 점수 + 추천 이유)

`GET /api/v1/lost-dogs/{lost_dog_id}/candidates/{notice_id}`

### Response `200` — Candidate 단일 객체 (위 items[0]과 동일 스키마)

---

## 5. 신규 후보 알림 목록

`GET /api/v1/lost-dogs/{lost_dog_id}/notifications`

### Response `200`

```json
{
  "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "items": [
    {
      "id": "ntf-001",
      "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "notice_id": "N20261101001",
      "title": "새로운 유사 후보가 있습니다",
      "body": "크림색 믹스견 공고가 유사 후보로 추가되었습니다. (총점 0.78)",
      "created_at": "2026-11-01T09:15:00+09:00",
      "read": false
    }
  ]
}
```

`POST /api/v1/notifications/{id}/read` — 읽음 처리 (`{"ok": true}`)

---

## 6. 공고 시드/수집 (서버 운영)

- `POST /api/v1/admin/seed` — 예시 공고 적재. 요청 헤더 `X-Admin-Key` 가 서버의 `ADMIN_API_KEY` 와 같아야 합니다. 키가 설정되지 않았거나 틀리면 403.
- `POST /api/v1/admin/collect?embed_images=true` — 공공 API 수집 (`SERVICE_KEY` 필요, `X-Admin-Key` 필수). 기본은 전국 공고중 전부 + 보호중 최근 90일 (1000건 × 페이지 끝까지), 사진 임베딩은 최대 3,000장씩 이어서 계산. 이미 수집이 돌고 있으면 409. 시작·예약 수집은 키 없이 서버 안에서 그대로 동작합니다.
- `GET /api/v1/notices/{notice_id}/photo?n=1|2` — 공고 사진 (서버 캐시 경유, CORS 허용). `size=thumb` 또는 `w=`(64–800) 이면 긴 변을 줄인 JPEG 미리보기
- `GET /api/v1/lost-dogs/{id}/photo` — 보호자가 올린 사진. 같은 `size`/`w` 미리보기 파라미터를 쓸 수 있습니다
- `GET /api/v1/system` — 모드(api/sample), 공고 수, 사진 임베딩 수, 텍스트·이미지 방식, 규칙 점수 배점(`pipeline.rule_points`)
  - 엔드포인트: `https://apis.data.go.kr/1543061/abandonmentPublicService_v2/abandonmentPublic_v2`
  - 포털: https://www.data.go.kr/data/15098931/openapi.do

---

## 매칭 점수 (규칙 점수 100점)

```
points = 품종 30 + 색상 25 + 지역 20 + 특징 15 + 날짜 10   (항목마다 만점 또는 0점)
```

- 품종: 정규화한 품종이 같음 / 색상: 공통 색상이 있음 / 지역: 시·도+시·군·구 표기가 같음 (실종 위치 ↔ 공고 orgNm, 없으면 발견 장소)
- 특징: 보호자 설명과 공고 특징의 공통 단어 / 날짜: 실종일 당일 또는 이후 구조 접수
- 점수 높은 순, 같으면 최근 접수 순. 실제 거리·사진 유사도는 계산하지 않습니다.
- 예전 방식으로 저장된 매칭 결과는 후보 목록·상세를 열 때 자동으로 다시 계산합니다.
- 웹 Mock 모드도 같은 기준을 씁니다 (`web/lib/matching/rule_points.dart`).
- 예전 멀티모달 공식(`backend/app/ai/fusion.py`)은 성능평가용으로 남아 있고 순위에는 쓰지 않습니다.

---

## 에러

| 코드 | 의미 |
|------|------|
| 400 | 잘못된 요청 |
| 404 | 실종견/공고 없음 |
| 500 | 서버 오류 |

```json
{ "detail": "lost dog not found" }
```


## 공고 둘러보기 (인증 불필요)

`GET /api/v1/notices/nearby?lat=&lng=&region=&kind=&color=&days=&radius=&page=&page_size=`

- 로그인 없이 보호소 공고를 거리순으로 봅니다.
- `lat`+`lng` 가 있으면 그 좌표가 기준, 없으면 `region`(시도/시군구, 기본 서울특별시) 중심입니다.
- `kind` 품종, `color` 색상, `days` 발견일 최근 N일, `radius` 반경(km), `page`/`page_size` 페이지.
- 응답: `origin_lat`, `origin_lng`, `origin_label`, `total`, `page`, `page_size`, `items[]`
  (사진 프록시, 품종, 색상, 발견 장소·날짜, `dist_km`, 보호소 이름·전화, 공고 기간 등).

`GET /api/v1/notices/{notice_id}` — 공고 상세 (인증 불필요).

실종견 등록의 `photo_data`/`photo_url` 은 선택입니다. 사진이 없으면 매칭에서 이미지 갈래를 빼고 나머지 점수로 다시 나눕니다.
