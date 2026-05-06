# Beta Data Standard Operating Procedure (SOP)

> v1.0 베타 사용자 데이터 회수 절차. PLAN.md G3 출시 게이트 대응.

## ⚠️  STATUS: TEMPLATE — 수신 채널 미확정

이 문서는 SOP **템플릿**이다. 베타 발송 전 두 가지 인간 결정이 필요:

  1. 메인테이너 수신 채널 (이메일 / GitHub Issues / Form 등) 확정
  2. §2 안내문의 `<maintainer-email-here>` 토큰을 실제 채널로 치환

이 결정 전까지 베타 사용자에게 본 안내문을 발송할 수 없다 →
**PLAN.md G3 출시 게이트는 INCOMPLETE**.

## 1. 무엇을 회수하는가

베타 단계에서 외부 분석 SDK는 도입하지 않는다 (PLAN.md 0.전제: 외부 송신 0).
대신 사용자가 **자신의 학습 백업 파일**을 본인 결정으로 메인테이너에게
전송하면 메인테이너가 **로컬에서** 분석한다.

회수 대상:
- `srsStates`: 카드별 SM-2 ease / intervalDays / reps / lapses / lastReview / dueDate
- `userOverrides`: hide / note 정보
- `schemaVersion`, `exportedAt`, `appVersion` 메타

회수하지 않는 것:
- `responseLatencies` (in-memory 한정, v1.0 export schema에 없음)
- 푸시 토큰, 사용자 식별자, 기기 정보 — 앱이 수집하지 않음
- 카드 본문 (VocabCard 번들은 메인테이너가 이미 보유)

## 2. 베타 사용자에게 보낼 안내문 (그대로 복사)

```
JLPTDeck 베타에 참여해 주셔서 감사합니다.

베타 1주차 / 4주차 끝에 학습 데이터를 한 번씩 보내 주시면 큰 도움이
됩니다. 보내실 데이터는 카드 학습 진도(SRS)와 카드 숨김 정보뿐이며,
개인 정보나 기기 정보는 포함되지 않습니다.

방법:
  1. 앱 → 설정 탭 → "백업 내보내기" → 파일 앱에 저장
  2. 저장된 jlptdeck-backup-YYYYMMDD-HHmm.json 파일을 다음 경로로 보내기:
     - 이메일: <maintainer-email-here>
     - 또는 메시지에 첨부

회신 의무는 없으며 언제든지 베타에서 빠져도 됩니다.
응답을 분석한 결과는 v1.1 업데이트 노트에 익명으로 요약합니다.
```

> 메인테이너 운영자: 위 `<maintainer-email-here>` 토큰을 실제 이메일로
> 치환한 뒤 베타 초대 메일/TestFlight Tester Notes에 붙여넣는다.
> v1.0 출시 직전 PLAN.md G3 체크리스트에서 확인.

## 3. 메인테이너 측 분석 절차

수신한 JSON 파일에서 다음 지표를 산출:

- D1, D7, D14 리텐션:
  `srsStates`의 `lastReviewUnix` 분포에서 `exportedAtUnix - lastReviewUnix`
  histogram → 익일 / 7일 / 14일 내 학습이 있었는지
- 평균 reps, 평균 lapses
- hidden 카드 ID 목록 → VocabCard JSON과 join → 어떤 카드가 자주 숨겨지는지
- F9 v1.x 활성화 결정 입력 (단, responseLatencies는 v1.0 export에 없음 —
  v1.1에서 schema v2로 확장 후 별도 회수)

분석 도구는 별도 리포지토리:
  `scripts/analyze_beta_export.py` (v1.0 + 30일 이후 작성 예정)

수신 파일은 메인테이너 로컬 vault (gitignore 처리)에 보관, 90일 후 폐기.

## 4. 보안 & 프라이버시 체크리스트

- [x] 외부 송신 0건 — `CP2_EVIDENCE/network_grep_F*.txt` 누적 0
- [x] 사용자 식별자 미수집 (UUID는 cardID, 사용자 ID 아님)
- [x] PII 미수집 (`note` 필드는 v1.0 UI 없음, 향후 입력 시 사용자 자기 책임)
- [x] 회수는 사용자 명시적 export + 본인 전송 (앱이 자동으로 보내지 않음)
- [x] 메인테이너 vault는 gitignore + 90일 폐기 정책

## 5. 출시 게이트 (PLAN.md G3)

- [ ] 본 문서 (`docs/beta-data-sop.md`) 존재 ✓ (이 파일)
- [ ] 메인테이너 이메일 토큰 치환 완료
- [ ] TestFlight Tester Notes에 §2 안내문 포함 확인
- [ ] 첫 베타 초대 발송 시 §2 본문 그대로 전달
- [ ] (post-v1.0) `scripts/analyze_beta_export.py` 작성

## 6. 한계 (정직 기록)

- 회수율은 사용자 자율 — 응답률 30% 미만이면 통계적 유의미성 약함
- D1/D7/D14는 `lastReviewUnix` 단일 시점 기반으로 추정 (앱 실행 횟수
  카운터가 아님). F15 (로컬 익명 이벤트 카운터)가 v1.0 출시 차단으로
  들어오면 별도 export field 추가 — 그 경우 schema v2 + 안내문 갱신.
- 메인테이너 1명 운영 가정. 데이터 처리 지연 SLA 없음.
