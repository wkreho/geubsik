# 급식

한동글로벌학교 학생이 오늘의 아침·점심·저녁을 바로 확인하는 모바일 앱과 웹을 만든다. 학교가 평소처럼 주간 식단표를 수정하면 수집기가 최신 JSON을 만든다. 학생이나 운영자가 메뉴를 다시 입력할 필요가 없다.

[웹에서 급식 보기](https://wkreho.github.io/geubsik/) · [최신 Android APK 다운로드](https://github.com/wkreho/geubsik/releases/latest/download/geubsik.apk) · [버전별 배포 및 업데이트 내역](https://github.com/wkreho/geubsik/releases)

## 배포 및 검증 상태

초기 개발과 웹·Android 정식 배포를 완료하고 유지보수 단계로 전환했다. 2026-11-26 사용자가 Phase 5-8-1 수정 후 Flutter 정적 분석 통과와 전체 테스트 **22/22 통과**를 확인하고 변경 사항을 커밋·푸시했다.

| 플랫폼 | 현재 배포 상태와 검증 범위 |
|---|---|
| 웹 | GitHub Pages에서 운영한다. 사용자가 Chrome에서 설정의 앱 정보, GitHub Releases 링크, 최신 APK 다운로드를 확인했다. |
| Android | 공개 버전은 v1.0.0(`1.0.0+1`, Universal APK, 약 20.5MB)이다. `apksigner` v1·v2 서명 검증, 배포 인증서 SHA-256 지문 일치, 실제 스마트폰 설치·기능 검증을 완료했다. |
| iOS | 프로젝트 구성과 앱 아이콘 적용만 완료했다. 실제 빌드·설치·배포는 진행하지 않았다. |

현재 소스에는 v1.0.0 공개 후 추가한 설정의 앱 정보 카드와 외부 링크 처리(`url_launcher` 6.3.2)가 있다. Releases 링크는 공통이고 APK 다운로드 항목은 웹 전용이다. 공개 APK에는 이 카드가 없으며, 이후 지정한 Android NDK `27.0.12077973`은 다음 Android 빌드에서 검증한다.

### 최초 급식 수집 기록

Python 오프라인 단위 테스트 16/16개를 통과했다. 최초 수집 시 Codex에서 DNS 오류(11001)가 발생했고, 사용자 PowerShell에서 연결을 확인하고 의존성을 설치한 뒤 비인증 XLSX 다운로드·파싱과 최초 JSON 생성을 완료했다.

| 항목 | 최초 수집 결과 |
|---|---|
| 워크시트 | 전체 54개 중 숨김 47개, 표시 7개. 표시 탭 중 급식과 무관한 탭 0개, 빈 주간표 4개, 포함한 주간표 3개 |
| 날짜 | 2026-11-16 ~ 2026-12-06의 21일. 메뉴가 있는 날 17일, 세 식사가 모두 빈 배열인 날 4일 |
| 스냅샷 | `schemaVersion` 1, `updatedAt`은 `2026-11-26T00:29:45.027097+09:00` |

생성된 JSON에서 날짜 정렬과 조식·중식·석식 배열을 확인했다. 한글, 원산지, 특식 안내와 셀 내부 줄바꿈은 보존됐고, 하단 공통 안내문은 제외됐다.

[학교 원본 · HIS 식단표 2026](https://docs.google.com/spreadsheets/d/1-H15GqsbE3APbGec7rNbw7_Cvm1UBq4mQpVF-Nw_74c)

## 수집과 데이터 정책

1. Python 표준 라이브러리로 공개 XLSX 내보내기 주소에 로그인 없이 GET 요청을 한 번 보낸다. 정상 리다이렉트를 허용하고 HTTP 상태, HTML 응답, ZIP 내부 구성과 워크북 로딩을 확인한다. 원본은 읽기 전용이며 다운로드 파일은 메모리에서만 사용한다.
2. openpyxl로 표시 상태인 워크시트만 읽는다. 과거 날짜도 포함하고 hidden 및 veryHidden 탭은 이름·메뉴를 기록하지 않는다. 급식과 무관한 표시 탭은 건너뛴다.
3. B2의 월요일에 0~6일을 더하고 B3:H3 날짜 및 B4:H4 요일을 대조한다. 연도 없는 월/일은 각 열에서 계산한 연도를 사용한다. 탭 이름·순서와 현재 날짜는 계산에 사용하지 않는다.
4. A열의 조식·중식·석식 사이에서 메뉴를 읽는다. 현 양식은 석식 7행 다음에 빈 구분 행 및 공통 안내가 이어진다. 미확인 하단 데이터가 나오면 경계를 추측하지 않고 중단한다. 한 셀은 문자열 하나다. 앞뒤 공백을 제거하고 줄바꿈을 LF로 통일한다. 내부 줄바꿈, 순서, 중복, 원산지, 특수문자는 보존한다.
5. 세 식사에 메뉴가 하나도 없는 주는 제외한다. 하나라도 있으면 빈 주말을 포함해 월~일 7일을 모두 담는다. 빈 배열은 그 식사의 메뉴가 등록되어 있지 않다는 뜻이다.
6. 매번 전체 스냅샷을 만든다. 메뉴 수정·삭제, 탭 숨김·삭제, 빈 양식 전환은 다음 정상 갱신에 반영한다. 다시 표시된 탭에 메뉴가 있으면 다시 포함한다. 별도 아카이브는 없지만 과거에 커밋한 급식 데이터는 Git 기록에 남을 수 있다.

## data/meals.json

| 필드 | 의미 |
|---|---|
| schemaVersion | 정수 1 |
| updatedAt | JSON을 처음 생성하거나 급식 내용이 변경되어 저장한 한국 시각. ISO 8601, +09:00 |
| meals | YYYY-MM-DD 키를 오름차순으로 정렬한 날짜별 객체 |
| 날짜별 breakfast, lunch, dinner | 모두 필수인 문자열 배열. 메뉴가 비어 있으면 빈 배열 |

원본 수정 시각과 매번 수집한 시각은 별도로 기록하지 않는다. schemaVersion과 meals가 같으면 기존 파일과 updatedAt을 그대로 유지한다. 출력은 UTF-8 한글, 두 칸 들여쓰기, 마지막 LF를 사용한다.

## Windows에서 실행

프로젝트 폴더에서 PowerShell을 연다. `python`이 사용할 Python 3.12 환경을 가리키면 아래 두 명령을 차례로 실행한다. `python -m pip`는 수집기를 실행할 Python 환경에 의존성을 설치한다.

~~~powershell
python -m pip install -r requirements.txt
python -B scripts/fetch_meals.py
~~~

별도 가상환경을 사용하려면 Python Launcher로 환경을 만들고 해당 환경의 실행 파일로 설치와 수집을 진행한다.

~~~powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe scripts/fetch_meals.py
~~~

Linux에서는 python3.12 -m venv .venv로 환경을 만들고 위 명령의 실행 파일을 .venv/bin/python으로 바꾼다. 네트워크는 의존성 설치 및 실제 원본 수집에만 필요하다.

전체 오프라인 테스트를 실행하는 명령은 다음과 같다.

~~~powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
~~~

테스트는 임시 폴더와 코드로 만든 워크북을 사용한다. 실제 수집 로그에는 탭·날짜 집계, 날짜 범위, 저장 여부가 표시된다.

## 실패 및 전체 빈 결과

학교가 식단표 양식을 바꾸면 `update-meals.yml`의 실패 로그와 마지막 정상 JSON을 확인한다. 문제가 생긴 주간 탭에서 날짜 머리글, 식사 구분 행, 공통 안내 시작 위치를 위 파싱 규칙과 대조한다. 바뀐 양식으로 회귀 테스트를 만든 뒤 수집기를 수정하고, 오프라인 테스트와 실제 추출 결과의 날짜·메뉴를 확인한다.

다운로드나 주간표 검증이 실패하거나 날짜가 겹치면 실행이 실패하고 기존 파일은 유지된다. 표시된 주간표가 모두 사라진 경우에도 원인을 판별할 수 없어 종료한다. 검증된 결과만 같은 폴더에 임시 파일로 완성한 뒤 원자적으로 교체한다. 처음 수집에 실패하면 예시 JSON을 만들지 않는다.

기존 메뉴가 있었는데 모든 표시 주간표가 빈 양식이 되면 경고와 함께 실패한다. 방학 등으로 원본이 실제 비어 있음을 확인한 담당자만 다음 명령을 사용한다. 검증 가능한 주간표가 있어야 하며 다운로드·파싱 오류에는 적용되지 않는다.

~~~powershell
.\.venv\Scripts\python.exe scripts/fetch_meals.py --allow-empty
~~~

기존 JSON에 문법 오류·중복 키·잘못된 스키마가 있으면 자동 복구하지 않는다. 담당자가 백업이나 Git에서 정상 파일을 복원한 뒤 갱신하거나, 손상본을 별도 보관한 뒤 새로 수집할 수 있다.

## GitHub 자동화

학교의 자동 추출·공개 재배포 허용을 확인하고 공개 저장소에서 워크플로를 활성화했다. 수동 실행으로 GitHub 서버에서 실제 XLSX를 추출하고 최초 JSON을 자동 커밋·푸시했다(`99e848d`). 실행 결과는 3개 주간표, 21일, 메뉴가 있는 날 17일이었다. 사용자가 브라우저에서 원격 JSON을 확인했다. [모바일·웹 공통 급식 JSON](https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json)

GitHub 내장 예약은 워크플로가 활성화된 상태에서도 실행 기록이 생성되지 않아 제거했다. 현재 cron-job.org가 30분마다 `workflow_dispatch` API에 POST 요청을 보낸다. 사용자가 외부 예약 활성화와 TEST RUN의 HTTP 200을 확인했다.

- 외부 서비스의 Fine-grained PAT는 `geubsik` 저장소에 한정하며 Actions 읽기·쓰기와 필수 Metadata 읽기 권한을 사용한다. 만료 전에 토큰을 갱신하고 외부 서비스의 인증값을 교체한다. 저장소와 로그에는 인증값을 남기지 않는다.
- 갱신이 멈추면 cron-job.org의 활성 상태·최근 HTTP 결과를 먼저 본다. 요청 실패는 엔드포인트·대상 브랜치·토큰 만료 및 권한을 확인한다. 요청이 성공했다면 GitHub Actions 실행 기록에서 다운로드·파싱·푸시 단계를 확인한다. 메뉴가 그대로면 커밋이 생기지 않을 수 있다.
- 수동 실행은 저장소의 Actions → Update meal data → Run workflow에서 대상 브랜치를 선택한다. 워크플로가 기본 브랜치에 있어야 한다.
- 같은 브랜치의 갱신은 직렬화한다. 수집 성공 후 변경된 data/meals.json만 커밋·푸시한다. 전체 테스트는 정기 수집에 포함하지 않는다. 푸시 충돌 시 강제 푸시하지 않고 실행이 실패한다.

[GitHub 예약 및 수동 실행 문서](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)

## Flutter 앱 실행과 데이터 흐름

Android·iOS·Web은 기존 `app/` 프로젝트를 공유한다. Flutter 3.32.8 stable, Dart 3.8.1, `http` 1.6.0, `shared_preferences` 2.5.3, `flutter_lints` 5.0.0을 사용한다. 의존성이 설치된 상태에서 저장소 루트의 PowerShell로 실행한다.

~~~powershell
cd app
flutter run -d chrome --no-pub
~~~

- `MealRepository`는 시작 시 공통 URL로 GET 요청을 보낸다. 제한 시간은 12초이며 수동 갱신은 쿼리가 붙은 URL을 사용한다.
- `MealSnapshot`과 `DailyMeals`는 UTF-8 응답의 버전, 변경 시각, 달력 날짜와 세 식사의 배열을 검증한다. `KoreaDate`는 UTC에 9시간을 더해 한국의 오늘을 구하고 달력 날짜끼리 이동·비교한다. 날짜가 누락된 경우와 등록된 날짜의 빈 메뉴를 구분한다.
- `MealController`는 ChangeNotifier로 캐시를 먼저 표시하고 원격 요청을 진행한다. 겹치는 갱신 요청은 하나로 합친다. 성공하면 빈 스냅샷까지 포함해 검증된 JSON 전체를 `SharedPreferencesAsync`로 교체한다. 요청 실패 시 기존 급식표를 표시하고, 저장 실패 시에도 받은 메뉴를 볼 수 있다.
- Phase 3에서 사용자가 Chrome에서 원격 JSON, 날짜 이동, 새로고침, 오프라인 캐싱을 확인했다.

## 화면과 설정

| 화면 | 동작 |
|---|---|
| 오늘 | 한국 기준 날짜와 식사별 카드, 이전·다음 날짜, 달력, 오늘 복귀, 당겨서 새로고침을 제공한다. 날짜가 없으면 등록된 모든 날짜로 이동할 수 있다. |
| 급식표 | 오늘부터 5일·7일, 이번 주·다음 주(월~일), 이번 달, 등록된 모든 날짜를 조회한다. 식사별 첫 메뉴를 펼치거나 날짜 제목을 눌러 상세 화면으로 이동한다. |
| 설정 | 테마·배경색·식사·메뉴 표시·빈 날짜 숨김을 바꾸거나 기본값으로 초기화한다. |

기본값은 시스템 테마, 회색 배경, 세 식사 모두, 전체 메뉴, 괄호 숨김 켜짐, 빈 날짜 숨김 꺼짐, 오늘부터 7일이다. 설정은 마지막 조회 기간과 함께 기기에 저장한다. 설정 초기화는 급식 캐시를 보존한다.

대표 메뉴는 특식 안내를 건너뛰고 첫 실제 메뉴 항목을 사용하며 그 항목의 여러 줄과 특식 안내를 함께 표시한다. 괄호 숨김을 끄면 원산지 등 원문을 확인할 수 있다. 표시 가공은 원본 JSON과 캐시를 변경하지 않는다. 달력의 활성 날짜는 모든 식사의 원본 메뉴를 기준으로 하고, 오늘은 항상 선택할 수 있다.

모바일은 세로 카드, 넓은 웹은 가로 식사 카드를 사용한다. 데스크톱 날짜 탐색 영역의 최대 너비는 420dp다. 첫 실제 항목의 메뉴 줄은 라이트 `#B94A4A`, 다크 `#F2A5A5`와 중간 굵기로 강조하고 특식 안내는 별도 색상으로 표시한다. 급식표의 식사 행을 누르면 메뉴와 화살표가 즉시 전환되며 키보드 포커스가 유지된다.

화면을 수정할 때는 `app/`에서 `flutter analyze --no-pub` 통과 후 `flutter test --no-pub`를 실행한다. Chrome에서 변경된 화면을 모바일·데스크톱 너비로 확인한다.

### 앱 아이콘

확정된 수저 아이콘 원본은 `app/branding/app_icon.png`(416×416)이다. Android에는 5개 밀도의 런처 아이콘과 배경·수저 전경을 분리한 적응형 아이콘을 적용했다. Android 13 이상에서 테마 아이콘을 켜면 단색 수저 레이어를 사용한다. iOS는 기존 AppIcon 규격에 맞춰 불투명 PNG 15개를 사용한다. 웹은 일반·마스크용 아이콘에 원본 구도를 유지하고, 파비콘만 바깥 여백을 줄여 작은 탭에서도 수저를 구분할 수 있게 했다.

PNG 규격과 참조 경로, Android·웹 마스크 안전 영역, 16px·32px 파비콘을 로컬에서 확인했다.

### Android Release APK

Android Release는 저장소 밖에 보관한 앱 전용 JKS로 서명한다. PowerShell에서 아래 명령으로 예시 파일을 최초 한 번 복사하고 두 비밀번호를 직접 입력한다. 이미 설정 파일이 있으면 편집기에서 기존 파일이 열린다.

```powershell
Set-Location 'C:\Users\SEC\Documents\GitHub\geubsik\app'
if (!(Test-Path android/key.properties)) {
    Copy-Item android/key.properties.example android/key.properties
}
notepad android/key.properties
```

`storeFile`은 예시처럼 슬래시(/)가 들어간 절대 경로로 적고 UTF-8(BOM 없음)로 저장한다. 비밀번호에 실제 역슬래시가 들어가면 Java properties 문법에 맞춰 `\\`로 입력한다. 실제 설정 파일과 서명키는 Git에서 제외하며 비밀번호를 문서·로그·GitHub Secrets에 남기지 않는다. 서명키와 비밀번호는 복구할 수 있도록 안전하게 백업한다.

같은 `app` 폴더에서 다음 명령으로 학생들이 설치할 단일 Universal APK를 빌드한다.

```powershell
flutter build apk --release --no-pub
```

빌드에 성공하면 저장소 기준 `app/build/app/outputs/flutter-apk/app-release.apk`가 생성된다. 같은 PowerShell에서 설치된 Android SDK Build Tools로 서명과 인증서를 확인한다.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --verbose --print-certs .\build\app\outputs\flutter-apk\app-release.apk
```

`Verifies`와 종료 코드 0을 확인하고 서명자 인증서 SHA-256 지문을 기존 배포용 지문과 대조한다.

**다음 Android 릴리스 절차**

1. APK 공개 배포 때 `app/pubspec.yaml`의 versionName과 versionCode를 함께 높인다(예: `1.0.1+2`). 웹만 배포할 때는 기존 버전을 유지한다. 설치된 앱이 업데이트될 수 있도록 `com.wkreho.geubsik`와 기존 배포 서명키를 유지한다.
2. 의존성 설치 후 위 명령으로 Universal APK를 빌드하고 서명·지문을 대조한다. 이번에 지정한 NDK `27.0.12077973`에서 빌드가 성공하고 기존 NDK 불일치 경고가 사라지는지 확인한다. 실제 기기에 이전 공개 버전을 설치한 상태에서 업데이트와 앱 동작을 확인한다.
3. GitHub Releases에 새 버전 태그로 Release를 만들고 검증한 APK를 `geubsik.apk`라는 이름으로 첨부한다. 이전 Release와 첨부 파일은 보존한다. 새 버전을 최신 정식 Release로 공개한 뒤 상단의 최신 APK 링크를 눌러 파일명을 확인한다. APK는 Release에만 첨부한다.

APK 링크가 끊기면 최신 정식 Release에 첨부된 파일명이 정확히 `geubsik.apk`인지 먼저 확인한다.

## Flutter Web 배포

웹 페이지는 Flutter 앱을 제공하고, 앱은 실행 시 기존 GitHub Raw URL에서 메뉴를 읽는다. `update-meals.yml`이 `data/meals.json`만 갱신하면 웹 빌드는 실행되지 않는다. [급식 웹사이트](https://wkreho.github.io/geubsik/)

1. 저장소의 **Settings → Pages → Build and deployment → Source**에서 **GitHub Actions**를 선택한다.
2. `main`에 `app/**` 또는 `.github/workflows/deploy-web.yml` 변경을 푸시하면 **Deploy Flutter Web**이 실행된다. 수동으로 배포하려면 **Actions → Deploy Flutter Web → Run workflow**에서 `main`을 선택한다.
3. `build` 작업이 Ubuntu에서 Flutter 3.32.8 stable을 설치하고 `app/`에서 `flutter pub get --enforce-lockfile`과 `flutter build web --release --no-pub --base-href /geubsik/ --pwa-strategy=none`을 실행한다. 로컬 Chrome 개발에는 기존 HTML의 `$FLUTTER_BASE_HREF` 플레이스홀더를 그대로 사용한다.
4. 빌드된 HTML의 base href와 진입 파일·리소스를 검사하고 `app/build/web`의 내용만 Pages artifact로 업로드한다. 성공하면 `deploy` 작업이 `github-pages` 환경에 게시한다. 빌드 결과물은 Git에서 제외하며 별도의 배포 브랜치나 PAT가 필요하지 않다.
5. 배포 후 Actions의 배포 URL을 열어 페이지를 새로고침하고 아이콘·화면·급식 데이터가 로드되는지 확인한다. 로컬 release 빌드는 선택 사항이다.

서비스 워커의 앱 사전 캐싱은 끈다. 이미 열린 앱은 원격 요청 실패 시 정상 급식 캐시를 표시할 수 있다. 오프라인에서 웹사이트를 처음 여는 기능은 보장하지 않는다. Pages·GitHub Raw의 HTTP 캐시 때문에 앱 코드나 메뉴 변경이 늦게 보일 수 있다. 웹 배포가 실패하면 Actions의 빌드 및 Pages 배포 로그를 순서대로 확인한다. 배포 성공 후 화면이 비면 게시 주소의 `/geubsik/` 경로와 브라우저에서 로드에 실패한 리소스를 확인한다.

[GitHub Pages 배포 워크플로 문서](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
