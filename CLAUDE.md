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
