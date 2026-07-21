# 🌤️ Mañana(마냐나) - 날씨와 문장, 손그림으로 기록하는 하루

<p align="center">
  <img src="./docs/images/logo.png" width="160"/>
</p>

<br/>

## 💛 Mañana - 배경

매일 아침, 오늘의 날씨는 어땠는지, 어떤 문장이 마음에 남았는지 금방 잊혀지곤 합니다.
Mañana는 그 하루를 사진이 아니라 **손으로 그린 그림**으로 남기고 싶다는 생각에서 출발한 iOS 앱입니다.

오늘의 날씨 배경 위에 오늘의 책 문장이 겹쳐지고, 사용자는 그 위에 손가락(또는 애플펜슬)으로 자유롭게 그림을 그려 하루를 기록합니다. 기록은 달력과 보관함에 쌓이고, 홈 화면·잠금화면 위젯을 통해 앱을 열지 않고도 오늘의 문장과 그림을 확인할 수 있습니다.

<br/>

## 💛 Mañana - 개요

*- 오늘의 날씨와 문장 위에, 손그림으로 하루를 남기다 -*

Mañana는 스페인어로 '내일'을 뜻합니다. 오늘 하루를 기록해두면 내일의 나에게 작은 선물이 된다는 의미를 담았습니다.

- 위치 기반으로 오늘의 날씨를 가져와 배경 아트워크로 보여줍니다.
- 매일 바뀌는 책 문장을 배경 위에 함께 띄웁니다.
- 사용자는 PencilKit 기반 캔버스에 직접 그림을 그려 하루를 기록합니다.
- 기록은 달력/보관함에서 다시 볼 수 있고, 이미지로 캡처해 공유할 수 있습니다.
- 홈 화면·잠금화면 위젯에서 앱을 열지 않아도 오늘의 문장과 그림이 자동으로 갱신됩니다.

<br/>

## 💛 주요 기능
---
- ### 오늘의 날씨 + 문장
    - 기상청(KMA) 단기예보 API를 Cloudflare Worker 프록시를 거쳐 받아온 날씨 정보를 바탕으로, 손그림 날씨 아트워크(맑음/흐림/비/눈 등)를 배경으로 보여줍니다.
    - 매일 Google Sheets에 정리된 문장 중 오늘의 문장이 배경 위에 함께 표시됩니다.
    - 큰 날씨 박스와 작은 날씨 박스를 접었다 펼 수 있습니다.
    <br/>
- ### 손그림 다이어리
    - PencilKit 기반 캔버스에서 펜/지우개/색상 팔레트로 자유롭게 그림을 그립니다.
    - 펜을 선택한 색상에 따라 펜촉만 색이 바뀌고 몸통은 검정으로 유지되는 손그림 스타일 아이콘을 사용합니다.
    - 다크 모드에서 검정/흰색 잉크가 반전되는 PencilKit 특성을 라이트 모드 강제 렌더링으로 해결해, 그림 색이 항상 그린 그대로 저장·공유됩니다.
    <br/>
- ### 달력 · 보관함
    - 그림을 그린 날짜는 달력에 표시되고, 보관함에서 날짜별 그림과 문장을 모아볼 수 있습니다.
    - 라이트/다크 모드 모두 적응형 텍스트 색상(`.primary`)으로 대응합니다.
    <br/>
- ### 공유하기
    - 실제 화면을 그대로 캡처해 이미지로 공유할 수 있습니다.
    <br/>
- ### 홈 화면 · 잠금화면 위젯
    - 작은 위젯은 오늘의 문장만, 큰 위젯은 날씨+문장+그림을 함께 보여줍니다.
    - 앱이 2주치 문장을 미리 App Group에 저장해두고, 위젯이 매 자정(KST)마다 스스로 타임라인 엔트리를 생성해 앱을 열지 않아도 자정에 맞춰 문장이 자동으로 갱신됩니다.
    - 잠금화면 위젯 2종(오늘의 문장 전용)을 함께 제공합니다.

<br/>

## ✔ 주요 기술
---

**iOS App**
- Xcode / XcodeGen (project.yml 기반 프로젝트 관리)
- SwiftUI (iOS 17+)
- UIKit (캔버스 커스터마이징, 라이트모드 강제 이미지 렌더링)
- SwiftData (로컬 데이터 저장)
- PencilKit (손그림 캔버스)
- Core Location (위치 기반 날씨)
- WidgetKit (홈 화면 / 잠금화면 위젯)

**Widget Extension**
- WidgetKit
- App Group (`UserDefaults(suiteName:)`, 공유 파일 컨테이너)로 앱 ↔ 위젯 데이터 공유 — 사이드로드 대응을 위해 App Group ID를 런타임에 동적 해석
- TimelineProvider — 앱이 미리 저장한 2주치 문장으로 매 자정 엔트리를 생성해 앱 실행 없이 자동 갱신

**외부 연동**
- 기상청(KMA) 공공데이터 — 날씨 정보
- Cloudflare Workers — 날씨 API 프록시 (서버 측 키 보관)
- Google Sheets (CSV export) — 오늘의 문장 데이터 관리

**배포 / 서명**
- xcrun devicectl (실기기 빌드/설치/실행)
- Local.xcconfig 분리 (개인 서명 정보를 공유 저장소에서 제외)
- Privacy Manifest / Export Compliance 대응 (App Store 심사 준비)
- AltStore / AltServer — 유료 Developer Program 없이 무료 계정으로 지속 배포
- `xcodebuild archive` + `exportArchive` — `.ipa` 파일 생성
- 별도 공개 저장소(`manana-releases`)의 `apps.json` — AltStore 소스 매니페스트로 앱 배포/업데이트 관리

**에셋 제작 도구**
- Python (PIL/Pillow) — 아이콘 크롭, 레이어 분리, 채우기 마스크 생성
- CoreText — 폰트 메트릭 측정

<br/>

## ✔ 서비스 아키텍처
---
<p align="center">
  <img src="./docs/images/architecture.png" width="90%"/>
</p>

<br/>

## ✔ 기술 스택 한눈에 보기
---
<p align="center">
  <img src="./docs/images/tech-stack.png" width="70%"/>
</p>

<br/>

## ✔ 프로젝트 파일 구조
---
```
Manana
  ├── App
  │   └── MananaApp.swift
  ├── Models
  │   ├── DailyQuote.swift
  │   ├── DiaryEntry.swift
  │   ├── Quote.swift
  │   ├── WeatherBackground.swift
  │   └── WeatherCondition.swift
  ├── Services
  │   ├── DrawingStorage.swift
  │   ├── KMAGrid.swift
  │   ├── LocationManager.swift
  │   ├── QuoteService.swift
  │   └── WeatherService.swift
  ├── Shared
  │   ├── ActivityView.swift
  │   ├── AppGroup.swift          (런타임 App Group ID 해석 — 사이드로드 대응)
  │   ├── Font+Manana.swift
  │   ├── SharedDrawingStore.swift
  │   └── SharedWeatherStore.swift
  ├── Views
  │   ├── ArchiveListView.swift
  │   ├── DiaryCalendarView.swift
  │   ├── DiaryEntryDetailView.swift
  │   ├── DrawingCanvasView.swift
  │   └── MainView.swift
  ├── Resources
  │   ├── Backgrounds
  │   └── Fonts
  └── Assets.xcassets
      ├── AppIcon
      ├── BigBox / MiniBox (날씨 박스 아트워크)
      ├── CalendarBackground
      ├── IconCalendar / IconShare / IconCrayon 등 (손그림 버튼 아이콘)
      └── weathericon_* (날씨별 아이콘 15종)

MananaWidget
  ├── CombinedWidget.swift        (홈 화면 큰 위젯 — 날씨+문장+그림)
  ├── DrawingWidget.swift          (홈 화면 작은 위젯 — 그림)
  ├── WeatherQuoteWidget.swift     (홈 화면 작은 위젯 — 문장)
  ├── QuoteLockScreenWidget.swift  (잠금화면 위젯)
  ├── QuoteLockScreenWideWidget.swift
  ├── WeatherEntryProvider.swift   (타임라인 프로바이더)
  ├── MananaWidgetBundle.swift
  ├── PrivacyInfo.xcprivacy
  └── Backgrounds

worker                              (Cloudflare Worker — 날씨 API 프록시)
  └── src

build                              (배포용 산출물 — gitignore)
  ├── Manana.xcarchive
  ├── exportOptions.plist
  └── export
      └── Manana.ipa

manana-releases                    (AltStore 배포 전용 공개 저장소 — 소스코드 없음)
  ├── apps.json                    (AltStore 소스 매니페스트)
  ├── Manana.ipa
  └── AppIcon.png
```

<br/>

## ✔ 협업 툴
---
- Git / GitHub
- Claude Code (AI 페어 프로그래밍)

## ✔ 협업 환경
---
- **개발 방식**: 기획/디자인을 맡은 사용자가 요구사항을 자연어로 전달하면, Claude Code가 코드를 구현하고 시뮬레이터·실기기에서 즉시 빌드해 결과를 확인시켜주는 방식으로 반복 개발
- **기능 단위 커밋**: 아이콘 교체, 위젯 개선, 버그 수정 등 기능 단위로 커밋 메시지를 작성하고 즉시 GitHub에 반영
- **실기기 우선 검증**: 시뮬레이터로 먼저 확인 후, 실제 아이폰에 설치해 최종 확인하는 2단계 검증 절차
- **외부 협업자 연동**: 친구가 별도로 기여한 기능(펜 아이콘 → 크레용 아이콘 교체, 위젯 자정 갱신 로직 등)을 GitHub을 통해 pull 받아 통합
- **무료 배포 파이프라인**: 유료 Apple Developer Program 없이도 실기기 사용을 지속할 수 있도록 AltStore 기반 배포 구조를 직접 설계 — 소스코드 저장소는 비공개, 배포 산출물만 별도 공개 저장소(`manana-releases`)에 분리

<br/>

## ✔ 트러블슈팅
---
- ### 사이드로드 후 위젯이 placeholder만 표시되는 문제
    - AltStore가 재서명하면서 번들 ID뿐 아니라 App Group ID까지 팀 ID를 붙여 바꿔버리는데(`group.com.wonji.manana` → `group.com.wonji.manana.<팀ID>`), 코드엔 원래 이름이 하드코딩돼 있어 앱과 위젯이 서로 다른 저장 공간을 바라보게 됨.
    - 런타임에 `embedded.mobileprovision`(프로비저닝 프로필)에서 실제 부여된 App Group을 읽어오는 `AppGroup` 헬퍼를 만들어 해결. 시뮬레이터/App Store 빌드에서는 선언된 기본값으로 폴백.
    <br/>
- ### 자정에 문장이 갱신되지 않는 문제
    - 기존엔 "내일 문장 1개"만 미리 저장하고 자정 엔트리 1개만 만들어, 앱이 켜져 있지 않으면 타임라인 재생성 시점에 어제 문장으로 되돌아가는 결함이 있었음.
    - 앱이 2주치 문장을 미리 App Group에 저장하고, 위젯이 다가오는 매 KST 자정마다 엔트리를 생성(`.atEnd` 정책)하도록 변경해 앱 실행 없이도 모든 홈/잠금화면 위젯의 문장이 정확히 갱신되도록 수정.
    <br/>
- ### 다크 모드에서 손그림 잉크 색상이 반전되는 문제
    - PencilKit의 순수 검정/흰색 잉크는 "적응형" 색상이라, 이미지로 렌더링하는 순간의 시스템 인터페이스 스타일(라이트/다크)에 따라 자동으로 반전되는 문제 발견.
    - 그림 저장 시점과 위젯용 이미지 렌더링 시점 모두 `UITraitCollection(userInterfaceStyle: .light).performAsCurrent { ... }`로 감싸 항상 라이트 모드 기준으로 렌더링하도록 수정.

<br/>

## ✔ 설치 방법 (AltStore, 무료 배포)
---
아직 App Store에 정식 출시되기 전까지, **AltStore**를 이용해 실기기에 설치하고 계속 사용할 수 있습니다. 컴퓨터(맥 또는 윈도우) 한 대가 필요합니다.

1. 아이폰 **설정 → 개인정보 보호 및 보안 → 개발자 모드** 켜기 (재시작 필요)
2. 컴퓨터에 [AltServer](https://altstore.io) 설치 후 실행
3. 아이폰을 연결하고 AltServer에서 **Install AltStore** 실행 (Apple ID 로그인 필요)
4. 아이폰 **설정 → 일반 → VPN 및 기기 관리**에서 개발자 프로필 신뢰
5. AltStore 앱 → **Sources → +**에서 아래 소스 주소 등록

   ```
   https://raw.githubusercontent.com/mananamanana/manana-releases/main/apps.json
   ```

6. **Browse** 탭에서 "마냐나" 검색 후 **INSTALL** (위젯까지 설치되도록 "Keep App Extensions" 선택)

이후 업데이트는 AltStore **My Apps** 탭의 **UPDATE** 버튼만 누르면 됩니다. 무료 Apple ID 서명은 7일마다 만료되므로, 같은 Wi-Fi에서 컴퓨터+AltServer를 켜두면 자동으로 갱신됩니다.

<br/>

## ✔ 개발 환경 실행
---
```bash
# 1. Xcode 프로젝트 생성 (XcodeGen)
xcodegen generate

# 2. 개인 서명 설정 (최초 1회)
cp Local.xcconfig.example Local.xcconfig
# Local.xcconfig에 본인 Apple Developer Team ID 입력

# 3. Xcode에서 Manana.xcodeproj 열고 실기기/시뮬레이터로 빌드
```
