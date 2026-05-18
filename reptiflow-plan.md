# ReptiFlow — 개발 기획서

> 파충류 브리더 & 샵 전용 운영 관리 플랫폼  
> 스택: Flutter · Supabase · Cloudflare R2 · Vercel (랜딩)

---

## 1. 핵심 컨셉

**"작업하면서 생각하지 않아도 되는 환경"**

| 기존 방식 | ReptiFlow |
|---|---|
| 엑셀 · 수기 · 카톡 메모 | 음성 기록 |
| 기억 의존 | 렉 시각화 |
| 개체 정보 흩어짐 | 자동 그룹화 |
| 분양 정보 수동 정리 | 분양 카드 1초 생성 |

---

## 2. 수익 모델

```
무료 플랜
  ├ 개체 20마리 제한
  └ 기본 기록만

Pro 플랜  (월 4,900~9,900원)
  ├ 무제한 개체
  ├ 클라우드 백업
  ├ 브리딩 기록
  ├ 렉 시스템
  ├ 분양 카드 자동 생성
  └ 통계 / 필터 전체

브리더 플랜  (추후)
  ├ 직원 계정 공유
  ├ QR 관리
  ├ 대량 등록
  └ 엑셀 export
```

---

## 3. 화면 구조 (하단 탭 5개)

```
[홈]  [렉]  [작업]  [캘린더]  [개체]
```

### 3-1. 홈 (Home)
- 오늘 해야 할 작업 카드 (급여 예정 N / 산란 예정 N / 해칭 D-N / 거부중 N)
- [작업 시작] 버튼
- 전체 개체 요약 카드 (암컷 N / 수컷 N / 베이비 N)

### 3-2. 렉 (Rack)
- 실제 렉처럼 격자 시각화 (3×9 등 사용자 정의)
- 칸 색상: 초록=급여완료 / 빨강=미급여 / 노랑=주의
- 슬롯 타입: 일반 · Split Tub (Front/Back) · 베이비 · 브리딩 · 산란
- 클릭 → 개체 미니 카드 오픈
- 드래그 → 슬롯 간 이동

### 3-3. 작업 (Work)
- [음성 작업 시작] 메인 버튼
- 음성 확인 시스템 (앱이 파싱 → "이렇게 기록할까요?" → 확인)
- 일괄 급여 기록, 청소 기록

### 3-4. 캘린더
- 급여 예정 · 산란 예정 · 해칭 예정 · 탈피 예정 · 몸무게 측정일
- 리스트형 표시 (오늘 / 이번 주 / 다음 산란)

### 3-5. 개체 (Reptiles)
- 검색 + 즉시 필터 (성별 · 모프 · 상태 · 급여그룹)
- 카드형 목록, 클릭 → 개체 상세

---

## 4. 개체 상세 (허브 화면)

```
상단
  ├ 커버 사진
  ├ 이름 · 모프 · 상태 배지
  └ 태그 (#거부중 #산란예정 ...)

중간 탭
  ├ 기록     — 급여 / 탈피 / 몸무게 타임라인
  ├ 혈통     — 부모 연결 · 형제 보기 · 자식 목록
  ├ 브리딩   — 메이팅 기록 · 산란 기록 · 해칭 D-Day
  ├ 미디어   — 사진 갤러리 · 짧은 영상
  └ 통계     — 급여율 · 체중 추이 그래프

하단 액션 버튼
  ├ [급여 기록]
  ├ [음성 기록]
  ├ [분양 프로필 생성]   ← 핵심 기능
  └ [상태 변경]
```

---

## 5. 분양 프로필 생성 시스템

개체 상세 → [분양 프로필 생성] 버튼

**선택 항목 체크박스 (순서 드래그 가능)**
- 이름 / 모프 / 성별 / 해칭일
- 부모개체 / 혈통 / 몸무게
- 특징 / 유전정보 / 급여상태

**결과물**
- 세로 카드형 이미지 (카톡 · DM 공유 최적화)
- 워터마크 자동 삽입 (브리더 브랜딩 + 도용 방지)
- 테마 선택: 다크 / 화이트 / 브리더

**템플릿 저장** → 다음부터 원클릭 생성

---

## 6. 개체 정보 필드

```
기본
  name, species, morph, sex, birthday/hatch_date
  father_id, mother_id, status, weight_g, tags[]

Status enum
  Active · Holdback · Reserved · Available · Sold · Deceased · Archived

Tags (예시)
  #거부중 #산란예정 #관찰필요 #탈피직전 #브리딩예정
```

---

## 7. 급여 시스템

```
레시피 (feeding_recipes)
  name: "암컷 산란기 슈프"
  components: { "레파시": 70, "칼슘": 20, "비타민": 10 }

급여 로그 (feeding_logs)
  status: 급여완료 · 부분섭식 · 거부

그룹 급여
  → "성체 암컷 전체에 산란기 레시피 적용"
```

---

## 8. 브리딩 시스템

```
메이팅 기록 (breeding_logs)
  male_id, female_id, paired_at, success

산란 기록 (egg_clutches)
  female_id, breeding_log_id
  laid_at, total_eggs, fertile, infertile
  expected_hatch_date (자동 계산)

해칭 D-Day 푸시 알림 자동 발송
주기 분석: 무정란 주기 · 산란 패턴 · 메이팅 추천 시기
```

---

## 9. 스마트 그룹 / 필터

자동 그룹 실시간 계산
```
암컷 34 / 수컷 18 / 베이비 41
레파시 22 / 일반 15 / 다이어트 6 / 거부중 3
```

조건 조합 필터
```
암컷 + 레파시 + 산란예정
```

---

## 10. DB 스키마

```sql
-- 핵심 테이블만 요약 (전체 ERD 별도 첨부)

users           id, email, name, plan
reptiles        id, user_id, father_id, mother_id, rack_slot_id
                name, species, morph, sex, birthday, status, tags[], weight_g
racks           id, user_id, name, rows, cols
rack_slots      id, rack_id, row, col, slot_type
feeding_logs    id, reptile_id, recipe_id, fed_at, status, memo
feeding_recipes id, user_id, name, components(jsonb)
breeding_logs   id, male_id, female_id, paired_at, success
egg_clutches    id, female_id, breeding_log_id, laid_at, total_eggs, fertile, infertile, expected_hatch
health_logs     id, reptile_id, recorded_at, weight_g, condition, memo
media           id, reptile_id, url, type, is_cover
profile_templates id, user_id, name, field_order(jsonb), theme(jsonb)
```

---

## 11. MVP 개발 순서

```
1단계  로그인 (Supabase Auth · 이메일 + 소셜)
2단계  개체 CRUD (기본 정보 입력 · 목록 · 상세)
3단계  사진 업로드 (Cloudflare R2 presigned URL)
4단계  렉 시스템 (격자 생성 · 슬롯 배치 · 드래그)
5단계  스마트 그룹 / 필터
6단계  급여 시스템 (레시피 · 일괄 기록 · 거부 처리)
7단계  브리딩 시스템 (메이팅 · 산란 · 해칭 D-Day)
8단계  캘린더 / 푸시 알림
9단계  음성 작업모드 (STT → 자동 파싱 → 확인)
10단계 분양 프로필 생성 (카드 이미지 export · 워터마크)
```

---

## 12. UI 원칙

- **다크모드 중심** (야간 작업 · 어두운 사육장 환경)
- **카드형 UI · 큰 터치영역** (한손 조작)
- **정보 점진적 공개** (목록엔 핵심만 → 눌러서 상세 전개)
- **한 화면 = 한 목적** (작업 화면에선 작업만)
- **POS기 느낌** (문서 관리 ❌ → 빠른 작업 ⭕)

---

## 13. 기술 스택

| 영역 | 기술 |
|---|---|
| 앱 | Flutter |
| 백엔드 / Auth / DB | Supabase |
| 파일 스토리지 | Cloudflare R2 |
| 랜딩 / 웹 | Next.js + Vercel |
| 개발 환경 | VS Code · Claude Code |
| CI/CD | GitHub → Vercel auto-deploy |

---

*ReptiFlow — 브리더가 작업하면서 생각하지 않아도 되는 환경*
