# Firebase App Distribution — 배포 가이드

> v1.0 베타 배포 채널. TestFlight 보완 또는 대체로 사용.
> Apple 심사 우회 가능 → 즉시 베타 발송, ~150명까지 무료.

## 정책 — 외부 송신 0 원칙 유지

**Firebase 통합 범위**:
- ✅ App Distribution (IPA 호스팅 + 테스터 알림)
- ❌ Firebase iOS SDK 통합 (Analytics / Crashlytics / Performance 모두 미도입)
- ❌ `GoogleService-Info.plist` 번들 추가
- 결과: 앱 바이너리는 여전히 네트워크 호출 0건. 메인테이너 머신(또는 CI)에서
  나간 IPA + 릴리즈 노트만 Firebase CDN에 도달. 사용자 행동 데이터 송신 0.

이 원칙은 FINAL.md §3 / CLAUDE.md "외부 송신 0"과 일치.
F15 베타 회수는 여전히 `docs/beta-data-sop.md` 수동 export 경로 사용.

---

## 1. 사람 작업 (Firebase 콘솔)

### 1.1. Firebase 프로젝트 생성
1. https://console.firebase.google.com → "프로젝트 추가"
2. 프로젝트 이름: `JLPTDeck` (또는 임의)
3. Google Analytics: **비활성화** (외부 송신 0 원칙)

### 1.2. iOS 앱 등록
1. 프로젝트 개요 → "iOS+" 아이콘 클릭
2. Apple 번들 ID: `com.jay.JLPTDeck`
3. 앱 닉네임: `JLPTDeck (Beta)`
4. App Store ID: 비워둠 (출시 후 채움)
5. 등록 후 표시되는 **앱 ID**(`1:1234567890:ios:abcdef...` 형식)를 복사.
   `.env` 또는 GitHub secret `FIREBASE_APP_ID`로 저장.
6. **GoogleService-Info.plist 다운로드 단계는 SKIP**. App Distribution은
   plist 불필요. 다운로드된 plist를 앱에 추가하지 마라 (FINAL §3 위반).

### 1.3. App Distribution 활성화
1. 왼쪽 메뉴 → "출시 및 모니터링" → "App Distribution"
2. "시작하기" 클릭
3. 테스터 그룹 생성:
   - `테스터 및 그룹` 탭 → `그룹 추가`
   - 그룹 alias (소문자/대시): `beta-testers`
   - 멤버 이메일 추가

### 1.4. 인증 자격 증명 (둘 중 하나)

**A. 서비스 계정 JSON** (CI 권장)
1. Firebase 콘솔 → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성"
2. JSON 다운로드 → 로컬에 안전하게 보관 (예: `~/.firebase/jlptdeck-sa.json`)
3. 권한 부여 (Google Cloud Console → IAM):
   - `Firebase App Distribution Admin`
4. 환경 변수 `GOOGLE_APPLICATION_CREDENTIALS=/절대경로/jlptdeck-sa.json`
5. CI 사용 시: 파일 내용을 base64 인코딩해 GitHub repo secret으로 등록.

```bash
base64 -i ~/.firebase/jlptdeck-sa.json | pbcopy
# → GitHub repo Settings → Secrets and variables → Actions → New secret
# Name: GOOGLE_APPLICATION_CREDENTIALS, Value: (붙여넣기)
```

**B. CLI 토큰** (로컬 1회성)
```bash
brew install firebase-cli       # 또는: npm i -g firebase-tools
firebase login:ci               # 브라우저 열림 → Google 로그인 → 토큰 표시
# 출력된 토큰을 `.env`의 FIREBASE_TOKEN=... 으로 저장
```

---

## 2. 사람 작업 (Apple Developer)

App Distribution은 IPA 호스팅이지 code signing은 직접 책임. 다음 자료가
**메인테이너 머신** (로컬 배포 시) 또는 **GitHub secrets** (CI 배포 시)에
있어야 함.

| 자료 | 발급 위치 | 비고 |
|---|---|---|
| Distribution Certificate (.p12) | Apple Developer Account → Certificates → Apple Distribution | 발급 후 keychain export로 .p12 추출, 패스워드 설정 |
| Ad-hoc Provisioning Profile | Apple Developer Account → Profiles → "Ad Hoc" | 테스터 디바이스 UDID 등록 필요 |
| App Store Connect API key (.p8) | App Store Connect → 사용자 및 액세스 → 통합 → 키 | TestFlight 대체 안 쓰면 생략 가능 |

UDID 수집:
- 테스터 → Settings → 일반 → 정보 → "식별자" 길게 누르기 → UDID 복사
- 또는 Firebase Distribution 사용 시 처음 가입 링크에서 자동 수집

---

## 3. 메인테이너 — 로컬 배포 절차

### 3.1. 1회 셋업
```bash
# Ruby + Bundler (macOS 시스템 ruby 2.6+ OK, 3.x 권장)
brew install rbenv
rbenv install 3.2.2 && rbenv local 3.2.2
gem install bundler

# 의존성 설치 (Gemfile + fastlane/Pluginfile)
bundle install --path vendor/bundle

# 환경 변수 (.env)
cp .env.example .env
# .env 편집 → FIREBASE_APP_ID, FIREBASE_TESTER_GROUPS, 인증 변수
```

### 3.2. 베타 배포 (한 번에)
```bash
bundle exec fastlane beta
```

이 명령은:
1. `xcodebuild archive`로 Release 빌드
2. `xcodebuild -exportArchive`로 ad-hoc IPA 생성 → `build/fastlane/JLPTDeck.ipa`
3. Firebase App Distribution에 업로드
4. `FIREBASE_TESTER_GROUPS`의 모든 테스터에게 이메일 알림 발송
5. 릴리즈 노트는 `AppStore/ko/release_notes_v1.0.0.txt` 또는
   `.env`의 `RELEASE_NOTES`

### 3.3. 이미 빌드된 IPA만 업로드
```bash
bundle exec fastlane beta_existing_ipa ipa_path:./build/fastlane/JLPTDeck.ipa
```

---

## 4. GitHub Actions — CI 자동 배포

워크플로: `.github/workflows/firebase-distribute.yml`
트리거: 수동 (Actions 탭 → "Firebase Distribute" → "Run workflow")

### 4.1. GitHub Secrets 등록
Settings → Secrets and variables → Actions → New repository secret:

| Name | Value |
|---|---|
| `FIREBASE_APP_ID` | `1:1234567890:ios:abcdef...` |
| `GOOGLE_APPLICATION_CREDENTIALS` | 서비스 계정 JSON base64 (한 줄) |
| `APPLE_DIST_CERT_BASE64` | `.p12` 인증서 base64 |
| `APPLE_DIST_CERT_PASSWORD` | `.p12` 패스워드 |
| `APPLE_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` base64 |

base64 인코딩 예:
```bash
base64 -i dist.p12 | pbcopy
base64 -i jlptdeck-adhoc.mobileprovision | pbcopy
```

### 4.2. 실행
1. Actions 탭 → "Firebase Distribute" 선택 → "Run workflow"
2. (선택) 릴리즈 노트 입력, 테스터 그룹 선택
3. 워크플로 완료 후 Firebase 콘솔에서 배포 확인
4. IPA artifact는 14일간 GitHub에 보관 (재배포용)

---

## 5. TestFlight 대안 결정

| 채널 | 장점 | 단점 |
|---|---|---|
| **Firebase App Distribution** | Apple 심사 우회, 즉시 배포, ~150명 무료, ad-hoc IPA | UDID 등록 필요, 테스터 명단 수동 관리 |
| **TestFlight** | UDID 불필요, 10,000명까지, 사용자 친화적 가입 | 베타 심사 1~2일 대기, 빌드당 90일 만료 |

v1.0 베타에서는 Firebase로 시작 (UDID 수집 기간을 활용해 초기 사용자 ~30명
대상 단계 진행), 일정 안정화 후 TestFlight로 전환 권장.

---

## 6. 트러블슈팅

### "code signing required"
- `EXPORT_METHOD=ad-hoc` 확인 (App Store 빌드는 `app-store`)
- Distribution cert가 키체인에 있고 unlocked인지 확인
- Provisioning profile에 테스터 UDID 포함됐는지 확인

### "401 Unauthorized" from Firebase
- 서비스 계정에 `Firebase App Distribution Admin` 역할 부여됐는지 확인
- `FIREBASE_APP_ID` 형식이 `1:NNN:ios:XXX`인지 확인 (project number 아님)

### "no provisioning profile matches"
- 번들 ID + cert + profile이 모두 같은 Apple Team에 속하는지 확인
- profile 만료일 확인 (1년 자동 만료)

### 외부 송신 0 원칙 확인
- 빌드 후 IPA 추출 → `strings JLPTDeck | grep -i firebase` → 결과 0건이어야 함
- 결과가 있다면 실수로 Firebase SDK가 통합된 것 — 즉시 제거

---

## 7. 출시 게이트 매핑 (PLAN.md §6)

본 가이드 완료 후:
- G3 (베타 회수 SOP) — 별개. `docs/beta-data-sop.md` 메인테이너 이메일
  토큰 치환 + Firebase 배포 발송 시 본문에 SOP §2 안내문 포함.
- G7 (LICENSE + attribution) — 영향 없음. App Distribution은 IPA 호스팅만.
- 비공식 추정 / 라이선스 attribution은 앱 내 Settings에서 변동 없음.

배포 1회 완료 후 `AppStore/README.md` §2.D (TestFlight Tester Notes)는
Firebase 사용 시 "Firebase Distribution 초대 메일 본문"으로 대체 해석.
