# Retiflow 개발 진행 현황

> 마지막 업데이트: 2025-05-17

---

## 프로젝트 개요

파충류 사육 관리 앱 (Flutter Web/Mobile)  
- 개체 등록·관리, 렉(Rack) 배치, 홈 대시보드  
- Supabase Auth + PostgreSQL + Cloudflare R2 이미지 스토리지

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| Framework | Flutter (Dart 3) |
| Backend | Supabase (Auth + PostgreSQL + RLS) |
| 이미지 스토리지 | Cloudflare R2 (S3 호환, AWS Signature V4) |
| 주요 패키지 | `supabase_flutter ^2.5.0`, `image_picker ^1.0.7`, `http ^1.1.0`, `crypto ^3.0.3` |
| 디자인 | 다크모드, 포인트 컬러 `#4CAF82` |

---

## Supabase 설정

- **URL**: `https://uutdigtsjwvjechcpkpd.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (main.dart 참조)

---

## DB 테이블

### `reptiles`
```sql
create table reptiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  species     text,
  morph       text,
  sex         text default 'unknown',   -- 'male' | 'female' | 'unknown'
  status      text default 'active',    -- 'active' | 'holdback' | 'available' | 'sold' | 'deceased'
  birthday    date,
  weight_g    double precision,
  memo        text,
  image_url   text,
  created_at  timestamptz default now()
);
-- RLS: auth.uid() = user_id
```

### `racks`
```sql
create table racks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  rows       int not null default 9,   -- 층 수 (1층이 맨 아래)
  cols       int not null default 3,   -- 열 수
  created_at timestamptz default now()
);
-- RLS: auth.uid() = user_id
```

### `rack_slots`
```sql
create table rack_slots (
  id          uuid primary key default gen_random_uuid(),
  rack_id     uuid not null references racks(id) on delete cascade,
  row_index   int not null,   -- 0 = 맨 위(최상층), rows-1 = 맨 아래(1층)
  col_index   int not null,   -- 0-based
  slot_type   text default 'normal',
  reptile_id  uuid references reptiles(id) on delete set null
);
-- RLS: rack_id in (select id from racks where user_id = auth.uid())
-- 슬롯 레코드는 개체 배치 시에만 INSERT, 제거 시 DELETE
```

> **층 번호 계산**: `floorNum = rack.rows - row_index` (row_index=0이 최상층)

---

## Cloudflare R2 설정

| 항목 | 값 |
|------|-----|
| Account ID | `5afe5db71ffd2677a9780686b33f9267` |
| Bucket | `reptile-images` |
| Access Key ID | `125f7112e973bd63b741d1053cafb5ca` |
| Public URL | `https://pub-10b6955917824b18a47d80c0f5fe1a1d.r2.dev` |
| 업로드 경로 | `{user_id}/{timestamp}.jpg` |
| 서명 방식 | AWS Signature V4 (HMAC-SHA256, region=auto) |

> CORS 설정 필요: R2 대시보드 → reptile-images 버킷 → Settings → CORS  
> `AllowedOrigins: ["*"], AllowedMethods: ["PUT","GET"], AllowedHeaders: ["*"]`

---

## 파일 구조

```
lib/
├── main.dart                         # 앱 진입점, AuthGate, HomeScreen (BottomNav 5탭)
├── utils/
│   └── r2_uploader.dart              # Cloudflare R2 이미지 업로드 (AWS Sig V4)
└── screens/
    ├── auth/
    │   ├── login_screen.dart         # 이메일/비밀번호 + Google OAuth 로그인
    │   └── signup_screen.dart        # 회원가입 (이메일+비밀번호+확인)
    ├── dashboard/
    │   └── dashboard_screen.dart     # 홈 대시보드
    ├── rack/
    │   ├── rack.dart                 # Rack, RackSlot, RackPosition 모델
    │   ├── rack_screen.dart          # 렉 목록 + 추가/삭제
    │   └── rack_detail_screen.dart   # 렉 그리드 상세 (배치/제거/드래그)
    └── reptiles/
        ├── reptile.dart              # Reptile 모델
        ├── reptile_form_widgets.dart # 공유 폼 위젯 + 종/모프 데이터
        ├── reptiles_screen.dart      # 개체 목록 (필터 + 렉위치 표시)
        ├── add_reptile_screen.dart   # 개체 추가
        └── edit_reptile_screen.dart  # 개체 수정/삭제
```

---

## 완료된 기능

### 인증
- [x] 이메일/비밀번호 로그인·회원가입
- [x] Google OAuth 로그인 (custom 4색 G 로고)
- [x] `AuthGate` — 세션 상태 따라 로그인/홈 자동 분기
- [x] 로그아웃

### 개체 관리 (`reptiles/`)
- [x] 개체 목록 (성별 필터: 전체/수컷/암컷, 새로고침)
- [x] 개체 카드 — 썸네일 사진, 이름, 모프/종, 몸무게, 렉 위치 (`A렉 3열 2층`)
- [x] 개체 추가 — 사진, 이름, 종/모프, 성별, 상태, 생일, 몸무게, 메모
- [x] 개체 수정 — 전체 필드 수정, 사진 교체
- [x] 개체 삭제 — 확인 다이얼로그
- [x] 종/모프 드롭다운 (기타 선택 시 직접 입력)
- [x] 이미지 업로드 — Cloudflare R2 (AWS Sig V4 직접 PUT)

**지원 종 목록**: 크레스티드게코 / 레오파드게코 / 볼파이톤 / 비어디드래곤 / 콘스네이크 / 블루텅스킨크 / 기타

**상태값**: 활성 / 홀드백 / 분양가능 / 분양완료 / 무지개다리

### 렉 관리 (`rack/`)
- [x] 렉 목록 — 이름, 열×층 표시
- [x] 렉 추가 다이얼로그 — 이름, 열 수(기본 3), 층 수(기본 9)
- [x] 렉 삭제
- [x] 렉 상세 그리드 — 열 헤더(하단), 층 번호(좌측, 역순: 위=최상층), 렉 이름(그리드 위 셀 영역 기준 중앙)
- [x] 슬롯 탭 → 빈 슬롯: 개체 선택 바텀시트(검색 지원) → 배치
- [x] 슬롯 탭 → 점유 슬롯: 개체 정보 + 제거 버튼
- [x] 드래그 앤 드롭 — 슬롯 간 이동, 점유 슬롯끼리 교체(swap)
- [x] 배치 요약 바 (배치됨 N / 비어있음 M)

**위치 표시 규칙**:
- `row_index = 0` → 최상층 (`rack.rows`층)
- `floorNum = rack.rows - row_index`
- 표시: `"{렉이름} {col+1}열 {floorNum}층"` (예: "1동 3열 2층")

### 홈 대시보드 (`dashboard/`)
- [x] 오늘 할 일 (급여/산란/해칭 예정 — UI만, 데이터 미연동)
- [x] 개체 현황 4개 가로 카드 (전체/암컷/수컷/미상)
- [x] 최근 등록 개체 가로 스크롤 (최근 5마리, 사진+이름+모프)
- [x] 스마트 그룹:
  - 전체 보유 개체 (active + holdback)
  - 분양가능 개체
  - 렉 배치 개체 / 렉 미배치 개체 (owned 기준)
  - [비활성 개체 ▼] 토글 → 분양 보낸 개체(sold)
  - [♥ 개체 ▼] 중첩 토글 → 무지개다리(deceased)
- [x] 하단 내비 [렉 관리] 탭 이동 콜백

---

## 미완성 / 다음 할 작업

### 우선순위 높음
- [ ] **급여 기록 기능** — `feedings` 테이블, 급여일·먹이 종류·급여량 기록
- [ ] **대시보드 오늘 할 일 연동** — 급여/산란/해칭 실제 데이터 표시
- [ ] **작업 탭** (`WorkScreen`) — 현재 `Center(child: Text('작업'))` 플레이스홀더
- [ ] **캘린더 탭** (`CalendarScreen`) — 현재 플레이스홀더

### 우선순위 중간
- [ ] **브리딩 기록** — 교배 날짜, 산란 날짜, 해칭 날짜, 클러치 수
- [ ] **체중 기록 히스토리** — 날짜별 몸무게 추이 그래프
- [ ] **개체 상세 화면** — 현재 edit_reptile_screen이 상세+수정 겸용, 전용 뷰 분리 고려
- [ ] **렉 이름 수정** — 현재 삭제만 가능, 이름 변경 기능 없음
- [ ] **스마트 그룹 탭 연결** — 그룹 카드 클릭 시 필터된 개체 목록으로 이동

### 우선순위 낮음
- [ ] **Push 알림** — 급여 예정일 알림
- [ ] **데이터 내보내기** — CSV/PDF 리포트
- [ ] **Google 캘린더 연동**
- [ ] **앱 아이콘 / 스플래시 화면** 커스터마이징
- [ ] **R2 이미지 삭제** — 개체 삭제 시 R2에서도 이미지 제거 (현재 DB 레코드만 삭제)

---

## 알려진 이슈

| 이슈 | 상태 |
|------|------|
| R2 CORS 미설정 시 이미지 업로드 실패 | R2 대시보드에서 수동 설정 필요 |
| 개체 삭제 시 R2 이미지 미삭제 | 구현 예정 |
| `flutter pub get` PowerShell에서 `&&` 미지원 | VS Code 터미널에서 실행 |
| Google OAuth redirectTo가 localhost 고정 | 배포 시 실제 도메인으로 변경 필요 |

---

## BottomNavigationBar 탭 구성

| 인덱스 | 탭 | 파일 | 상태 |
|--------|-----|------|------|
| 0 | 홈 | `dashboard_screen.dart` | 완료 |
| 1 | 렉 | `rack_screen.dart` | 완료 |
| 2 | 작업 | `main.dart` (WorkScreen) | 플레이스홀더 |
| 3 | 캘린더 | `main.dart` (CalendarScreen) | 플레이스홀더 |
| 4 | 개체 | `reptiles_screen.dart` | 완료 |
