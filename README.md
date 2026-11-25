# 급식

한동글로벌학교 학생이 오늘의 아침·점심·저녁을 바로 확인하는 모바일 앱과 웹을 만든다. 학교가 평소처럼 주간 식단표를 수정하면 수집기가 최신 JSON을 만든다. 학생이나 운영자가 메뉴를 다시 입력할 필요가 없다.

## 현재 단계와 구성

로컬 작업 경로는 `C:\Users\SEC\Documents\GitHub\geubsik`, 현재 브랜치는 `main`이다. [GitHub 저장소](https://github.com/wkreho/geubsik)

Phase 1의 로컬 수집 검증과 Phase 2의 GitHub Actions 수동 실행 검증을 완료했다. Phase 3에서는 `app/`의 Flutter 앱이 GitHub Raw에서 급식표를 읽고 기기에 저장하는 기능과 임시 확인 화면을 구현했다. Phase 4에서 최종 UI를 구현할 예정이다. GitHub Pages는 미설정이다.

### 2026-11-26 로컬 검증 결과

오프라인 단위 테스트는 16/16 통과했다. Codex 환경에서는 DNS 이름 해석 오류(`getaddrinfo failed`, 11001)로 다운로드에 실패했다. 사용자 Windows PowerShell에서는 `docs.google.com` 이름 해석과 HTTPS 443 연결에 성공했다. 첫 실행에서 `openpyxl`이 없어 중단됐지만, 같은 Python 환경에 `python -m pip install -r requirements.txt`로 의존성을 설치한 뒤 `python -B scripts/fetch_meals.py`로 실제 XLSX를 인증 없이 다운로드하고 워크북을 파싱해 최초 `data/meals.json`을 생성했다. Codex 환경의 DNS 제한은 여전히 남아 있다.

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

다운로드나 주간표 검증이 실패하거나 날짜가 겹치면 실행이 실패하고 기존 파일은 유지된다. 표시된 주간표가 모두 사라진 경우에도 원인을 판별할 수 없어 종료한다. 검증된 결과만 같은 폴더에 임시 파일로 완성한 뒤 원자적으로 교체한다. 처음 수집에 실패하면 예시 JSON을 만들지 않는다.

기존 메뉴가 있었는데 모든 표시 주간표가 빈 양식이 되면 경고와 함께 실패한다. 방학 등으로 원본이 실제 비어 있음을 확인한 담당자만 다음 명령을 사용한다. 검증 가능한 주간표가 있어야 하며 다운로드·파싱 오류에는 적용되지 않는다.

~~~powershell
.\.venv\Scripts\python.exe scripts/fetch_meals.py --allow-empty
~~~

기존 JSON에 문법 오류·중복 키·잘못된 스키마가 있으면 자동 복구하지 않는다. 담당자가 백업이나 Git에서 정상 파일을 복원한 뒤 갱신하거나, 손상본을 별도 보관한 뒤 새로 수집할 수 있다.

## GitHub 자동화

학교의 자동 추출·공개 재배포 허용을 확인하고 공개 저장소에서 워크플로를 활성화했다. 수동 실행으로 GitHub 서버에서 실제 XLSX를 추출하고 최초 JSON을 자동 커밋·푸시했다(`99e848d`). 실행 결과는 3개 주간표, 21일, 메뉴가 있는 날 17일이었다. 사용자가 브라우저에서 원격 JSON을 확인했다. [모바일·웹 공통 급식 JSON](https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json)

30분 주기 예약은 설정했으며 실제 예약 실행 기록은 아직 확인하지 않았다.

- 예약 실행은 기본 브랜치에서 UTC 매시 7분·37분이다. 부하에 따라 지연될 수 있으며 공개 저장소가 60일간 비활성 상태면 예약이 비활성화될 수 있다.
- 수동 실행은 저장소의 Actions → Update meal data → Run workflow에서 대상 브랜치를 선택한다. 워크플로가 기본 브랜치에 있어야 한다.
- 같은 브랜치의 갱신은 직렬화한다. 수집 성공 후 변경된 data/meals.json만 커밋·푸시한다. 전체 테스트는 정기 수집에 포함하지 않는다. 푸시 충돌 시 강제 푸시하지 않고 실행이 실패한다.

[GitHub 예약 및 수동 실행 문서](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)

## Flutter 앱 실행과 데이터 흐름

Android·iOS·Web은 기존 `app/` 프로젝트를 공유한다. Flutter 3.32.8 stable, Dart 3.8.1, `http` 1.6.0, `shared_preferences` 2.5.3, `flutter_lints` 5.0.0을 사용한다. 의존성이 설치된 상태에서 저장소 루트의 PowerShell로 실행한다.

~~~powershell
cd app
flutter run -d chrome --no-pub
~~~

- `MealRepository`는 시작 시 공통 URL로 GET 요청을 보낸다. 제한 시간은 12초이며 수동 갱신은 쿼리가 붙은 URL을 사용한다. 브라우저의 실제 CORS·캐시 동작은 확인이 필요하다.
- `MealSnapshot`과 `DailyMeals`는 UTF-8 응답의 버전, 변경 시각, 달력 날짜와 세 식사의 배열을 검증한다. `KoreaDate`는 UTC에 9시간을 더해 한국의 오늘을 구하고 달력 날짜끼리 이동·비교한다. 날짜가 누락된 경우와 등록된 날짜의 빈 메뉴를 구분한다.
- `MealController`는 ChangeNotifier로 캐시를 먼저 표시하고 원격 요청을 진행한다. 겹치는 갱신 요청은 하나로 합친다. 성공하면 빈 스냅샷까지 포함해 검증된 JSON 전체를 `SharedPreferencesAsync`로 교체한다. 요청 실패 시 기존 급식표를 표시하고, 저장 실패 시에도 받은 메뉴를 볼 수 있다.
- 임시 화면에서 날짜 이동·오늘 복귀, 세 식사, 데이터 변경 시각·출처, 수동 갱신과 재시도를 확인할 수 있다. 정적 분석과 오프라인 테스트는 각각 `app/`에서 `flutter analyze --no-pub`, `flutter test --no-pub`로 실행한다.

Phase 3 검증 상태(2026-11-26): Dart 파일 포맷을 완료했다. Codex의 쓰기 허용 범위 밖에 있는 Flutter SDK 캐시 잠금 파일 때문에 정적 분석 명령이 결과를 내지 못해 중단했다. Flutter 테스트 13개는 작성했으며 실행 결과는 아직 없다. 사용자 PowerShell에서 위 분석·테스트 명령으로 확인할 수 있다.

## Flutter Web 배포 계획

앱은 공통 Raw URL에서 데이터를 받으므로 메뉴 갱신 때 앱을 재빌드할 필요가 없다. 기본 GITHUB_TOKEN으로 푸시한 커밋은 일반적인 후속 push 워크플로나 브랜치 기반 Pages 빌드를 트리거하지 않는다. Flutter Web 빌드·배포 방식은 후속 단계에서 결정한다.

[GitHub 워크플로 트리거](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) · [Pages 게시 소스](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
