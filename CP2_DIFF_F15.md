# CP2_DIFF_F15 — 로컬 익명 이벤트 카운터 (D1/D7)

## 변경 파일
**신규**:
- `JLPTDeck/Data/Models/AppOpenEvent.swift` — `@Model` (id, date) — 4번째 SwiftData 엔티티
- `JLPTDeck/Domain/SRS/RetentionStats.swift` — pure helper (`Snapshot`, `snapshot(eventDates:now:calendar:)`)
- `JLPTDeckTests/SRS/RetentionStatsTests.swift` — 9 단위 테스트
- `JLPTDeckTests/Data/AppOpenEventPersistenceTests.swift` — 1 active (schema smoke) + 2 disabled (host crash)
- `scripts/add_f15_files.rb`

**수정**:
- `JLPTDeck/Domain/FeatureFlags.swift` — `eventCounter: Bool = true`
- `JLPTDeck/JLPTDeckApp.swift` — Schema에 `AppOpenEvent.self` + init() 끝에 `repo.recordAppOpen(at: Date())` (best-effort, try?)
- `JLPTDeck/Data/Repository/LocalRepository.swift` — protocol에 `recordAppOpen(at:)` + `appOpenEventDates()` + 구현
- `JLPTDeck/App/Dependencies/LocalRepositoryClient.swift` + `LocalRepositoryClient+Live.swift` — Sendable 클로저 2개 추가
- `JLPTDeck/Features/Stats/StatsView.swift` — `#if DEBUG` `debugRetentionSection` (`stats.debugRetention` accessibility ID), `loadStats()`에서 retention 계산

## 핵심 로직

**모델** (4번째 SwiftData 엔티티 — 자동 마이그레이션):
```swift
@Model final class AppOpenEvent {
    var id: UUID
    var date: Date
}
```

**Pure RetentionStats** (Domain):
```swift
public enum RetentionStats {
    public struct Snapshot {
        let installDate: Date?
        let totalOpenDays: Int        // 고유 calendar day count
        let d1Retained: Bool?         // nil = 아직 D1 미달
        let d7Retained: Bool?         // nil = 아직 D7 미달
        let lastOpenDate: Date?
    }
    public static func snapshot(eventDates: [Date], now: Date, calendar: Calendar = .current) -> Snapshot
}
```
- D1 = install + 1 day에 이벤트 있음
- D7 = install + 1 ~ install + 7 윈도 안에 이벤트 1개라도
- 같은 calendar day는 한 번만 카운트
- 충분한 시간이 경과 안 한 경우 nil 리턴 (false 아님 — "아직 모름")

**Recording**:
```swift
// JLPTDeckApp.init() 끝부분
if FeatureFlags.eventCounter {
    let repo = SwiftDataLocalRepository(modelContext: container.mainContext)
    try? repo.recordAppOpen(at: Date())   // best-effort
}
```

**StatsView debug section** (DEBUG only, eventCounter ON only):
- 고유 학습일 / D1 리텐션 / D7 리텐션 표시
- accessibilityIdentifier `stats.debugRetention` (수동 QA용)

## 테스트 결과
- 신규 9 (`RetentionStatsTests`): empty / single-event / d1 true|false / d7 true|false / dedup same-day / lastOpen max / flag default — 모든 경계값 + nil 표기 케이스
- 신규 1 active (`AppOpenEventPersistenceTests.test_schemaSmoke_acceptsAllFourEntities`): 4-entity schema CRUD smoke
- 신규 2 disabled (`disabled_test_recordAppOpen_roundTrip`, `disabled_test_recordedEvents_drivesRetentionSnapshot`): host-deinit crash, L9 의존
- 회귀: **108/108 green** (CP2_EVIDENCE/test_F15.txt) — F13 rev2 98 + 9 + 1
- 빌드: BUILD SUCCEEDED (CP2_EVIDENCE/build_F15.txt)
- **외부 송신 grep: 0건** (CP2_EVIDENCE/network_grep_F15.txt) — DoD 핵심 요건 충족 ✓

## 알려진 한계
1. **Repository round-trip 자동 테스트는 disabled** — host crash. F8/F13과 같은 카테고리. L9 의존. Schema smoke + pure stats 테스트 + 수동 QA로 보완.
2. **Recording은 init당 1회** — 같은 launch 내 백그라운드/포그라운드 전환 시 추가 이벤트 X. 충분 (DAU/D1/D7는 calendar day 단위).
3. **Recording은 best-effort `try?`** — 실패 시 silent. 사용자에게 retention 데이터가 빠질 뿐, app launch 자체는 성공. 의도된 동작.
4. **DEBUG only 표시** — release 빌드에서는 retention 데이터가 SwiftData에 쌓이지만 UI 노출 없음. 베타에서 `docs/beta-data-sop.md` 회수 시 메인테이너가 직접 분석. v1.x에서 release UI 노출 검토.
5. **F9 `responseLatencies` 와 별개** — F15는 calendar-day 단위 retention만. F9 per-attempt latency는 in-memory 한정 (F13 schema v2 검토 사항).
6. **JLPTDeckApp init이 main actor** — 가정 OK (SwiftUI App protocol). Swift 6 strict mode 경고 0건 (F15 신규 코드).

## 롤백
- **재빌드**: `FeatureFlags.eventCounter = false` → `recordAppOpen` skip + `debugRetentionSection` hide. SwiftData 기존 `AppOpenEvent` rows는 보존 (재활성 시 복구).
- **부분**: JLPTDeckApp init의 recordAppOpen 호출만 제거 (Schema는 유지).
- **완전**: 4 신규 파일 + 테스트 2개 삭제 + JLPTDeckApp/LocalRepository/Client/StatsView git revert + Schema에서 AppOpenEvent 제거. SwiftData 자동 마이그레이션 (역방향)으로 데이터 자동 폐기.
- **데드라인** (PLAN.md §4): D-5. 빠질 경우 베타 단계 D1/D7 측정 채널 부재 → v1.1 마케팅 출시 차단 조건(KPI 측정) 충족 불가.

F15 ready for review
