# JLPTDeck

## 프로젝트 스펙
- iOS 17+, SwiftUI, SwiftData
- SRS 알고리즘: SM-2
- 데이터: JMdict (N4~N1 번들 포함, 약 21,200단어)
- 카드: 단어 중심형 (한자 앞면 → 읽기+뜻 뒷면)
- 온보딩: 레벨 선택 → 일일 학습량 설정
- JLPT 레벨: N4, N3, N2, N1

## 아키텍처 원칙
- Domain Layer는 순수 Swift로 격리 (Android 포팅 대비)
- SRSEngine은 독립 모듈로 분리 (추후 FSRS 교체 가능하도록)

## 워커 분리 기준
- Task 1: SM-2 엔진 + SRSState SwiftData 모델
- Task 2: JMdict 파싱 + 단어 번들 + Repository
- Task 3: FlashcardView + OnboardingView + ReviewSessionView

## 아키텍처 — The Composable Architecture (TCA)
- UI 레이어는 점진적으로 **TCA** (pointfreeco/swift-composable-architecture 1.15+) 로 전환 중. 새 피처는 **반드시 TCA로 작성**.
- 프로젝트 로컬 skill: `.claude/skills/tca-architecture.md` 를 먼저 읽을 것. Reducer 형태, 의존성 주입, 네비게이션, 테스트 패턴이 모두 거기에 박제되어 있음.
- 기존 `@Observable` 클래스(`OnboardingViewModel`, `ReviewSessionViewModel`)는 마이그레이션 대기 중. 해당 피처를 건드릴 때 Reducer 로 변환.
- Domain 레이어(`Domain/SRS/`, `Domain/Quiz/`)는 순수 Swift 로 TCA와 무관하게 유지.
- Data 레이어(`Data/Repository`, `Data/JMdict`)는 `LocalRepository` 프로토콜 그대로. TCA 에선 `@Dependency` 키로 래핑.
