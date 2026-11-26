# 급식 작업 지침

프로젝트 루트는 `C:\Users\SEC\Documents\GitHub\geubsik`이며 현재 브랜치는 `main`이다. [GitHub 저장소](https://github.com/wkreho/geubsik)

한동글로벌학교 학생이 한국 시각 기준 오늘 급식을 빠르게 볼 수 있도록 한다. 학교의 기존 입력 흐름만 사용하고 학생·운영자에게 메뉴 재입력을 요구하지 않는다.

## 유지보수 기준

웹과 Android의 초기 개발·정식 배포를 완료했다. 향후 작업은 운영 장애나 요청된 변경의 영향 범위에 맞춘다. 급식 갱신, 웹 배포, Android 배포는 각각 독립적으로 운영한다. [운영 웹사이트](https://wkreho.github.io/geubsik/) · [최신 Android APK](https://github.com/wkreho/geubsik/releases/latest/download/geubsik.apk) · [버전별 Release](https://github.com/wkreho/geubsik/releases)

- 최종 검증은 사용자가 Phase 5-8-1 수정 후 수행했다. Flutter 정적 분석과 전체 테스트 22/22개가 통과했고 Chrome에서 앱 정보, 외부 링크와 실제 APK 다운로드를 확인했다. 변경 사항은 커밋·푸시했다.
- 공개 Android v1.0.0 이후의 소스에는 앱 정보 카드와 Releases 링크가 있다. APK 다운로드 항목은 웹에서만 표시한다. 공개 APK에는 카드가 없으며, 웹만 변경할 때에는 Android 버전을 유지한다.
- iOS는 프로젝트와 아이콘만 구성했다. 실제 빌드·설치·배포는 진행하지 않았다.

## 급식 수집과 데이터 계약

`scripts/fetch_meals.py`와 `tests/test_fetch_meals.py`는 Python 3.12와 openpyxl을 사용한다. `.github/workflows/update-meals.yml`은 공개 XLSX를 인증 없이 읽고 검증에 성공한 뒤 변경된 JSON만 GitHub 기본 토큰으로 푸시한다.

원본은 [HIS 식단표 2026](https://docs.google.com/spreadsheets/d/1-H15GqsbE3APbGec7rNbw7_Cvm1UBq4mQpVF-Nw_74c)이다. ID는 1-H15GqsbE3APbGec7rNbw7_Cvm1UBq4mQpVF-Nw_74c, 내보내기 경로는 /export?format=xlsx 이다. 원본은 읽기 전용이며 XLSX 전체를 저장소에 남기지 않는다.

| 위치 | 파싱 규칙 |
|---|---|
| C1 부근, A2:B2 | 주간 식단표 제목, Week of, 월요일 시작일. 이름이 불규칙한 탭에서 날짜를 추론하지 않는다. |
| B3:H3, B4:H4 | 월~일의 날짜 및 영문 요일을 계산 결과와 대조한다. 연말에 열마다 연도가 달라질 수 있다. |
| A열 조식·중식·석식 | 라벨로 구역을 정한다. 현 메뉴 영역은 B5:H12, B14:H20, B22:H28이다. |
| 하단 | 구분 행과 30행 이후 공통 안내문·알레르기 목록을 제외한다. 뜻이 불명확한 경계는 오류로 처리한다. |

- 표시된 주간표만 처리한다. hidden 및 veryHidden의 내용은 출력하지 않는다. 빈 양식은 제외한다. 과거 날짜라도 표시되고 메뉴가 한 개 이상이면 그 주 7일을 전부 저장한다.
- 각 날짜의 breakfast, lunch, dinner는 문자열 배열이다. 빈 배열은 미등록을 뜻한다. 원본 셀 순서, 내부 줄바꿈·괄호·기호·중복은 보존한다.
- 최상위에는 schemaVersion(정수 1), updatedAt(Asia/Seoul 시각), meals(정렬된 ISO 날짜 키)가 있다. 기존과 내용이 같으면 파일과 시각을 유지한다.
- 매번 전체를 재생성하여 숨김·삭제·수정·재표시를 반영한다. 과거 버전은 Git 기록에 남을 수 있다. 파싱 실패·날짜 충돌은 기존 파일을 보존한다. 전체 빈 결과의 보호 및 명시적 예외는 README를 따른다.
- 다운로드·파싱·저장을 분리한다. 새 구조에 맞춰 수정할 때 검증을 조용히 생략하거나 기존 데이터에 누적하지 않는다.

## 수집 운영

학교가 자동 추출·공개 재배포를 허용했다. 최초 검증에서 Python 테스트 16/16개가 통과했고, 사용자 PowerShell과 GitHub Actions에서 실제 XLSX를 파싱했다. 최초 자동 갱신 커밋은 `99e848d`이며 탭·날짜 집계는 README의 최초 수집 기록을 따른다.

cron-job.org가 30분마다 GitHub의 `workflow_dispatch` API를 호출한다. 외부 예약용 fine-grained PAT는 이 저장소의 Actions 읽기·쓰기와 필수 Metadata 읽기로 제한한다. 만료 전에 갱신해 cron-job.org의 인증값을 교체하고 요청 결과와 Actions 실행 기록을 확인한다. 인증값을 저장소나 로그에 남기지 않는다.

## 앱 데이터와 캐시

- 기존 `app/`의 Android·iOS·Web 프로젝트를 사용한다. Flutter 3.32.8, Dart 3.8.1, http 1.6.0, shared_preferences 2.5.3, url_launcher 6.3.2, flutter_lints 5.0.0 및 SDK의 flutter_test를 기준으로 한다.
- 공통 데이터 URL은 [GitHub Raw 급식표](https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json)이다. 앱은 `MealRepository`를 통해 UTF-8 JSON을 읽고 `MealSnapshot`·`DailyMeals`로 검증한다. 수집기는 독립적으로 운영한다.
- 한국 날짜는 `KoreaDate`로 계산한다. 시각을 UTC+09:00 기준 날짜로 변환한 후 달력 날짜끼리 이동한다. 메뉴 미등록과 날짜 미포함을 구분한다.
- `MealController`(ChangeNotifier)가 유효한 캐시를 먼저 표시하고 중복 요청을 합친다. 검증한 응답은 빈 스냅샷도 포함해 전체 교체하고 `SharedPreferencesAsync`에 저장한다. 잘못된 응답은 캐시를 보존하고, 저장 실패 시에도 원격 데이터를 표시한다.

## 화면과 설정

오늘·급식표·설정 탭은 같은 `MealController`를 사용한다. 오늘은 모바일 세로·넓은 화면 가로 식사 카드로 표시한다. 여러 날짜는 기간별 목록에서 펼치거나 날짜 상세로 이동한다. 한국 날짜가 바뀌면 오늘을 갱신한다.

설정 기본값은 시스템 테마, 회색 배경, 세 식사 모두, 전체 메뉴, 괄호 숨김 켜짐, 빈 날짜 숨김 꺼짐, 오늘부터 7일이다. 설정과 기간은 급식 캐시와 다른 키에 저장한다. 특식·대표 메뉴·괄호 가공은 표시 계층에서만 수행한다. 달력의 활성 여부는 원본 전체 식사를 기준으로 하며 오늘은 예외다. 빈 날짜 숨김은 급식표 탭에서만 선택 식사에 적용한다.

`app/`에서 `flutter analyze --no-pub` 통과 후 `flutter test --no-pub`를 실행하고 `flutter run -d chrome --no-pub`로 확인한다. 실제 UI의 좁은 폭·다크 모드·오프라인·재실행 설정 복원을 검증한다.

대표 메뉴는 첫 실제 항목의 메뉴 줄을 공통 테마로 강조하고 특식 안내는 별도로 표시한다. 급식표의 접힌 식사 행은 아이콘·이름·대표 메뉴를 함께 표시한다. 각 행의 `InkWell`은 클릭 물결과 누름·호버 배경을 끄고, 48dp 최소 높이와 키보드 포커스를 유지한다. 펼치면 해당 식사의 전체 메뉴와 화살표가 즉시 전환된다.

## 웹 자동 배포

- `.github/workflows/deploy-web.yml`은 `main`의 `app/**` 또는 워크플로 자체가 변경될 때 실행한다. 수동 배포는 **Actions → Deploy Flutter Web → Run workflow → main**에서 실행한다. 저장소 관리자가 **Settings → Pages → Source → GitHub Actions**를 설정한다.
- Ubuntu 빌드 작업은 Flutter 3.32.8 stable과 `app/pubspec.lock`을 사용한다. `--base-href /geubsik/`로 빌드하며 원본 HTML에는 Flutter 플레이스홀더를 유지한다. 빌드 결과 검사 후 `app/build/web`만 artifact로 전달하고 배포 작업이 `github-pages`에 게시한다. 빌드 결과물은 커밋하지 않는다. [급식 웹사이트](https://wkreho.github.io/geubsik/)
- 급식 수집 워크플로·외부 예약과 웹 배포를 독립적으로 유지한다. 앱은 기존 Raw URL로 데이터를 조회한다. `--pwa-strategy=none`을 사용하며 실행 중 급식 캐시와 오프라인 웹 시작을 구분한다. Pages와 Raw의 HTTP 캐시로 변경 반영이 늦어질 수 있다.
- 웹 장애는 Actions의 빌드 → Pages 배포 로그 → 게시 주소의 리소스 로딩 순서로 확인한다. 급식 데이터만 오래됐다면 수집 워크플로와 Raw JSON을 확인한다.

## 플랫폼 아이콘

- 기준 파일은 `app/branding/app_icon.png`(416×416 RGB)다. 각 플랫폼 PNG는 원본을 Lanczos로 리샘플링한다.
- Android는 기존 `@mipmap/ic_launcher`를 사용한다. API 26부터 적응형 아이콘에 원본 배경색 `#BECEE3`과 투명 수저 전경을 사용한다. API 33부터 같은 실루엣의 단색 레이어도 제공한다.
- iOS는 `AppIcon.appiconset/Contents.json`의 19개 항목에 불투명 정사각형 PNG 15개를 연결한다. 웹은 기존 상대 경로로 일반·마스크용 192px·512px 아이콘과 32px 파비콘을 제공한다. 파비콘은 원본 중앙의 272×272 영역을 사용한다.
- PNG 해상도·디코딩, 리소스 참조, Android·웹 안전 영역과 파비콘 축소본을 확인했다.

## Android 서명과 수동 배포

- 사용자가 생성한 전용 JKS는 저장소 밖에 보관한다. 사용자가 `app/android/key.properties.example`을 같은 폴더의 `key.properties`로 복사해 두 비밀번호를 직접 입력한다. 실제 설정 파일·서명키는 Git에서 제외하고 비밀번호를 코드·로그·문서·GitHub Secrets에 남기지 않는다.
- Android 앱 모듈의 Kotlin DSL은 Release에 전용 서명 구성을 연결한다. 필수 설정이 없으면 Release APK 패키징이 실패한다. Android Debug와 GitHub Pages 웹 빌드에는 Release 서명 정보가 필요 없다.
- `app/`에서 `flutter build apk --release --no-pub`로 Universal APK를 생성한다. 저장소 기준 출력 경로는 `app/build/app/outputs/flutter-apk/app-release.apk`다. 배포 전 README의 `apksigner verify --verbose --print-certs` 명령으로 서명과 인증서를 확인한다.
- 첫 공개 버전은 v1.0.0(`1.0.0+1`, 약 20.5MB)이다. 사용자가 Universal APK 빌드, v1·v2 서명 검증, 배포용 SHA-256 지문 대조와 실제 스마트폰 설치·기능 검증을 완료했다.

- 다음 Android 공개 배포 시 `app/pubspec.yaml`의 versionName과 versionCode를 모두 높인다. 동일한 applicationId `com.wkreho.geubsik`와 비공개 배포키를 유지하고 이전 버전에서 실기기 업데이트를 확인한다. 검증한 APK를 새 태그의 정식 Release에 `geubsik.apk`로 첨부하고 최신으로 지정한다. 이전 버전과 첨부 파일을 보존한다.
- `shared_preferences_android` 요구 사항에 맞춰 지정한 NDK `27.0.12077973`은 다음 Android Release 빌드에서 빌드 성공과 경고 해소를 확인한다.

## 장애 점검

- 다운로드가 실패하면 최신 정식 Release의 첨부 파일명이 `geubsik.apk`인지 확인한다. 기존 앱 위에 업데이트가 실패하면 applicationId, 서명 인증서 지문, versionCode를 이전 배포와 대조한다.

- 급식 갱신 실패 시 cron-job.org 요청과 Actions 로그부터 확인한다. 학교 양식이 바뀌면 주간 날짜·식사 경계·안내문 위치를 대조하고 변경 사례를 재현하는 테스트를 추가한 뒤 파서를 수정한다. 정상 JSON은 보존하고 검증 후 갱신한다.

## 협업

일반 ChatGPT는 기획·요구사항·기술 검토·프롬프트 작성·결과 검토를 맡고 Codex는 로컬 구현·파일 관리·검증·결과 보고를 맡는다. 해당 단계에 필요한 파일만 확인하고 기존 사용자 작업을 보존한다. 앱 기능이나 미정인 배포 방식을 임의로 확정하지 않는다.

작업당 전체 오프라인 테스트는 최대 1회 실행한다. 모두 통과한 경우에만 실제 수집을 최대 1회 실행한다. 실패하면 원인·관련 파일·가능한 조치를 보고하고 다음 요청을 기다린다. 전체 코드·JSON·긴 로그 대신 파일 역할, 집계, 미검증 사항을 간단히 보고한다.
