# CP2_REVIEW_F15 — PASS_WITH_WARNING

[판정] PASS_WITH_WARNING

## 검증 대상
- `CP2_DIFF_F15.md`
- `PLAN.md` F15 DoD: `AppOpenEvent` SwiftData 모델 + 앱 launch 시 기록 + StatsView 디버그 영역에서 D1/D7 미리보기 + 외부 송신 0건 grep 검증
- `FINAL.md` 의도: 외부 분석 SDK 없이 로컬 D1/D7 카운터를 둔다

## 통과 근거
- `JLPTDeck/Data/Models/AppOpenEvent.swift`에 `@Model AppOpenEvent(id: UUID, date: Date)`가 추가됐다.
- `JLPTDeck/JLPTDeckApp.swift`에서 `FeatureFlags.eventCounter`가 켜져 있으면 app init 시 `SwiftDataLocalRepository(...).recordAppOpen(at: Date())`를 best-effort로 호출한다.
- `JLPTDeck/Data/Repository/LocalRepository.swift`에 `recordAppOpen(at:)`와 `appOpenEventDates()`가 구현되어 `AppOpenEvent`를 SwiftData에 insert/fetch한다.
- `JLPTDeck/Domain/SRS/RetentionStats.swift`는 D1/D7을 pure helper로 계산하고, `RetentionStatsTests`가 nil/true/false/dedup/lastOpen 경계를 검증한다.
- `JLPTDeck/Features/Stats/StatsView.swift`에 DEBUG 전용 `stats.debugRetention` 섹션이 있고, `AppOpenEvent` fetch 결과로 D1/D7을 표시한다.
- `CP2_EVIDENCE/test_F15.txt` 기준 108/108 green, `CP2_EVIDENCE/build_F15.txt` 기준 build succeeded다.

## F15 고유 질문 답변

[외부 송신 grep 0 확인?]  
확인했다. `CP2_EVIDENCE/network_grep_F15.txt`는 출력이 비어 있고, F15 코드 경로에 네트워크 송신 API가 없다.

[UUID 생성 시점/저장 위치?]  
`AppOpenEvent.init(id: UUID = UUID(), date: Date = .now)`에서 이벤트 row마다 UUID를 생성하고 SwiftData `AppOpenEvent.id`에 저장한다. 사용자 고정 식별자가 아니라 launch event row ID다.

## 남은 경고
- `AppOpenEvent`는 아직 F13 `ExportPayload`에 포함되지 않는다. 따라서 베타 사용자 데이터를 외부 SDK 없이 회수하려면 F13 schema v2 또는 별도 이벤트 로그 export가 필요하다. 현재 상태만으로는 여러 베타 사용자의 D1/D7 KPI를 모을 수 없다.
- `AppOpenEventPersistenceTests`의 실제 `recordAppOpen → fetch → RetentionStats` 테스트는 disabled이고, active 테스트는 4-entity schema smoke뿐이다. pure 계산은 검증됐지만 repository round-trip 자동 증거는 약하다.
- `recordAppOpen` 실패는 `try?`로 묵살된다. 앱 실행을 막지 않는 선택은 타당하지만, 이벤트 누락을 사용자가 알 방법은 없다.
- release 빌드에서는 StatsView 디버그 섹션이 숨겨진다. v1.0 베타에서 사용자가 직접 확인할 수 있는 통계가 아니라 maintainer/debug 확인용이다.
- `docs/beta-data-sop.md`는 아직 F15 이벤트를 회수 대상으로 포함하지 않고, 수신 채널도 미확정이다. 이 경고는 F13/G3 차단 게이트와 연결된다.

## 결론
F15 단독 DoD인 “로컬 기록 + DEBUG 미리보기 + 외부 송신 0”은 충족했다.  
다만 F15가 실제 베타 KPI 회수로 이어지려면 F13/G3 쪽 export/수신 채널 미완료가 반드시 닫혀야 한다.
