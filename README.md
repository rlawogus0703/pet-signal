# 펫 시그널 (Pet Signal) — 10조 학회 시연 스타터

실종견과 공공 구조동물 공고를 **유사 후보**로 매칭하고, 품종·색상·거리·날짜·특징·나이·**사진·텍스트(AI)** 항목별 추천 이유를 보여주는 서비스입니다.

> 결과는 동일 개체로 단정하지 않습니다. 공고 원문(animal.go.kr)과 사진을 보호자·보호소가 직접 확인합니다.

## 팀 역할 (10조)

| 역할 | 담당 | 범위 |
|------|------|------|
| 웹 클라이언트 | **재현** | Flutter Web (로그인·회원가입 / 등록 / 후보 목록 / 추천 이유 / 알림) |
| 모바일 앱 | **민재** | Flutter App — 동일 API 사용 |
| 백엔드 | TBD | FastAPI + DB + 수집기 + 매칭 엔진 |

공유 계약: [`API_SPEC.md`](./API_SPEC.md)

## 아키텍처

```mermaid
flowchart LR
  subgraph Data["데이터"]
    PUB["공공 API\n구조동물 공고"]
    TXT["텍스트 특징\n품종·색상·특징·나이"]
    IMG["이미지 특징\n공고/보호자 사진"]
    PUB --> TXT
    PUB --> IMG
  end

  subgraph AI["AI 유사도 매칭"]
    TS["텍스트 유사도\nsentence-transformers"]
    IS["이미지 유사도\nCLIP / 히스토그램 fallback"]
    MM["멀티모달 융합\n+ 규칙점수"]
    TS --> MM
    IS --> MM
  end

  subgraph Out["매칭·추천"]
    CAND["유사 후보 + 항목별 이유"]
  end

  subgraph Clients["클라이언트"]
    WEB["웹 (재현)"]
    APP["앱 (민재)"]
  end

  TXT --> TS
  IMG --> IS
  MM --> CAND
  CAND --> WEB
  CAND --> APP
```

규칙 기반(품종 동의어·색상·Haversine 거리·날짜·키워드·나이)은 항상 동작하고, AI 모델(`requirements-ai.txt`)은 **선택**입니다. 모델이 없으면 색상 히스토그램·키워드/해시 임베딩으로 fallback 합니다.

## 폴더 구조

```
pet-signal/
  API_SPEC.md          # 공유 REST 계약 (+ /auth/*)
  README.md
  web/                 # Flutter Web (재현) — 기본 Mock 모드
  backend/             # FastAPI + SQLite/PostgreSQL
```

---

## Windows에서 웹 실행 (재현님) — Mock 기본

Flutter SDK: `C:\dev\flutter` · 프로젝트를 `C:\dev\pet-signal` 에 복사했다고 가정.

```bat
set PATH=C:\dev\flutter\bin;%PATH%
cd C:\dev\pet-signal\web
flutter pub get
flutter run -d chrome
```

VS Code: `C:\dev\pet-signal\web` 열고 디바이스 Chrome 선택 후 Run.

### 학회 시연 순서 (추천)

1. **홈**: 히어로, 95,685마리 통계, 문제/해결, "흰색 말티즈 vs 크림색 믹스견" 정규화 예시, 4단계 동작 방식.
2. **「예시로 바로 체험하기」** 버튼 → 데모 로그인 + 논문 예시 실종견(콩이, 흰색 말티즈, 오산시 양산동) 등록 → **유사 후보** 화면.
   - 1위: 오산시 원동 **크림색 믹스견**(일반 검색이면 빠지는 후보), 2위: 화성시 봉담 흰색 말티즈.
3. 후보 카드 클릭 → **추천 이유 상세**: 항목별 점수 막대 8개(AI 2개 포함), 추천 이유 문장, 내 강아지 vs 후보 비교, 보호소 연락처·공고 원문 버튼.
4. **알림** 탭: 신규 후보 알림(안 읽음 표시, 모두 읽음), **마이페이지**: 내 실종견 목록·로그아웃.
5. 직접 등록을 보여줄 땐 **실종견 등록** → 「논문 예시로 채우기」 또는 사진 업로드 후 직접 입력.

### 바로가기 URL (시연용)

| 주소 뒤에 붙이기 | 화면 |
|---|---|
| `?demo=1` | 데모 로그인 + 예시 실종견 → 유사 후보 |
| `?demo=1&detail=1` | 1위 후보 상세 |
| `?demo=1&tab=3` | 알림 (`tab`: 0 홈 · 1 등록 · 2 후보 · 3 알림 · 4 마이페이지) |
| `?login=1&tab=1` | 데모 로그인 후 등록 화면 |

- 데모 계정: `demo@petsignal.kr` / `demo1234` (Mock 모드에 미리 생성, API 모드에서는 없으면 자동 가입)
- 회원가입/로그인 화면은 한 화면에서 탭으로 전환됩니다.
- 상단 **Mock 시연 모드** 버튼 → API 서버 모드로 전환 (서버 주소 입력). 모드를 바꾸면 로그인이 초기화됩니다.

### 오프라인(인터넷 없는 발표장) 대비

- 글꼴(Pretendard), 강아지 사진 17장, CanvasKit을 전부 앱에 포함했습니다.
- 빌드: `flutter build web --release --no-web-resources-cdn` → `build\web` 폴더를 아무 정적 서버로 실행
  (예: `cd build\web` 후 `python -m http.server 8080` → http://localhost:8080/?demo=1 ).

### 웹 구조 (lib/)

```
main.dart                 앱 시작 + URL 바로가기(?demo=1 등)
theme/app_theme.dart      디자인 시스템 (코랄 #FF6B4A + 네이비 #16233F, Pretendard)
state/app_state.dart      전역 상태: Mock/API 모드, 로그인, 내 실종견, 알림 수
state/demo.dart           논문 예시 실종견 + 원클릭 시연
screens/shell.dart        반응형 레이아웃 (넓은 화면: 사이드 메뉴 / 모바일: 하단 탭)
screens/home_screen.dart  랜딩 (히어로·통계·동작 방식·기술 구성)
screens/auth_screen.dart  로그인 / 회원가입
screens/register_screen.dart   3단계 등록 폼 + 사진 업로드 + 미리보기
screens/candidates_screen.dart 후보 카드 그리드 + 정렬/필터 + 스켈레톤
screens/detail_screen.dart     항목별 점수·추천 이유·비교·보호소 연락
screens/notifications_screen.dart, my_page_screen.dart
matching/scorer.dart, normalizer.dart, explain.dart   웹 내장 매칭 엔진 + 추천 이유 문장
data/mock_data.dart       예시 공고 16건 (tools/gen_notices.py 로 생성, 서버 시드와 동일)
```

예시 공고를 고치려면 `tools/gen_notices.py` 를 수정하고 `python tools/gen_notices.py` 를 실행하세요
(`web/lib/data/mock_data.dart` 와 `backend/data/seed_notices.json` 이 같이 바뀝니다).
사진 출처: `web/assets/PHOTO_CREDITS.md` (Wikimedia Commons, CC 라이선스).

---

## Windows에서 백엔드 실행 (SQLite, SERVICE_KEY 불필요)

```bat
cd C:\dev\pet-signal\backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m scripts.seed_data
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- API 문서: http://127.0.0.1:8000/docs
- 헬스: http://127.0.0.1:8000/health
- 시작 시 예시 공고 16건 자동 시드 (예전 8건 DB가 남아 있으면 `petsignal.db` 를 지우고 다시 실행하면 깔끔해요)
- 콘솔 출력은 Windows 한글 콘솔(cp949)에서도 깨지지 않게 처리되어 있어요
- PostgreSQL: `set DATABASE_URL=postgresql+psycopg://user:pass@localhost:5432/petsignal`
- 공공 API 실수집: `set SERVICE_KEY=발급키` (https://www.data.go.kr/data/15098931/openapi.do )
- (선택) AI 모델: `pip install -r requirements-ai.txt`

웹에서 API 연동: 앱 상단 토글을 **API**로 바꾼 뒤, 같은 계정으로 회원가입/로그인.

테스트:

```bat
cd C:\dev\pet-signal\backend
.venv\Scripts\activate
pytest -q
```

---

## 인증 API 요약

- `POST /auth/signup` — 회원가입 (이메일, 비밀번호, 이름, 전화 선택)
- `POST /auth/login` — 로그인 → JWT
- `GET /auth/me` — Bearer 토큰으로 내 정보
- `POST /api/v1/lost-dogs` — Bearer 있으면 `user_id` 연결

상세 JSON은 `API_SPEC.md` 참고.

## 다음 단계

1. 백엔드 담당 확정 후 PostgreSQL·스케줄러 주기·가중치 튜닝
2. 공공 API 키 발급 후 `SERVICE_KEY`로 실공고 수집
3. 민재 앱과 API_SPEC 동기화 (`age`, `image`/`text`, auth)
4. FCM 푸시는 시연용 알림 화면으로 대체 가능 → 이후 연동
