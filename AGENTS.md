# 급식 작업 지침

프로젝트 루트는 `C:\Users\SEC\Documents\GitHub\geubsik`이며 현재 브랜치는 `main`이다. [GitHub 저장소](https://github.com/wkreho/geubsik)

한동글로벌학교 학생이 한국 시각 기준 오늘 급식을 빠르게 볼 수 있도록 한다. 학교의 기존 입력 흐름만 사용하고 학생·운영자에게 메뉴 재입력을 요구하지 않는다.

## 현재 구현

Phase 1은 `scripts/fetch_meals.py`, `tests/test_fetch_meals.py`, `.github/workflows/update-meals.yml`에 들어 있다. Python 3.12가 공개 XLSX를 인증 없이 읽고 openpyxl로 분석한다. 워크플로는 `workflow_dispatch`로 실행하며 정상 수집 후 변경된 JSON만 기본 토큰으로 푸시한다.

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

## 검증 결과 및 현재 단계

2026-11-26 기준 Phase 1 로컬 구현 및 검증을 완료했다. 전체 오프라인 단위 테스트는 16/16 통과했다. Codex에서는 DNS 이름 해석 오류(11001)로 수집이 중단됐다. 사용자 Windows PowerShell에서 `docs.google.com` DNS와 HTTPS 443 연결을 확인한 후, 첫 실행에서 누락된 `openpyxl` 등 의존성을 `python -m pip install -r requirements.txt`로 설치했다. 이어서 `python -B scripts/fetch_meals.py`로 실제 XLSX 비인증 다운로드, 워크북 파싱, 최초 `data/meals.json` 생성을 완료했다. Codex 환경의 DNS 제한은 남아 있다.

- 전체 탭 54개 중 숨김 47개, 표시 7개였다. 표시 탭 중 무관한 탭은 0개, 빈 주간표는 4개였으며 3개 주간표를 포함했다.
- 2026-11-16 ~ 2026-12-06의 21일 중 17일에 메뉴가 있고 나머지 4일은 세 식사가 모두 빈 배열이다. 최초 파일의 `schemaVersion`은 1, `updatedAt`은 `2026-11-26T00:29:45.027097+09:00`이다.

Phase 2에서 학교의 자동 추출·공개 재배포 허용을 확인했다. GitHub Actions 수동 실행으로 실제 다운로드·파싱, 최초 JSON 자동 커밋·푸시(`99e848d`)를 검증했다. 내장 schedule에 실행 기록이 생성되지 않아 cron-job.org의 30분 주기 POST → `workflow_dispatch`로 전환했다. 사용자가 외부 예약 활성화와 TEST RUN HTTP 200을 확인했다. Fine-grained PAT는 해당 저장소의 Actions 읽기·쓰기 및 필수 Metadata 읽기로 제한하고 만료 전에 교체한다. 실패 시 외부 서비스의 요청 기록·대상 브랜치·권한·만료를 확인한 후 Actions 로그를 확인한다. 인증값을 조회하거나 기록하지 않는다.

## Phase 3 앱 구현

- 기존 `app/`의 Android·iOS·Web 프로젝트를 사용한다. Flutter 3.32.8, Dart 3.8.1, http 1.6.0, shared_preferences 2.5.3, flutter_lints 5.0.0 및 SDK의 flutter_test를 기준으로 한다.
- 공통 데이터 URL은 [GitHub Raw 급식표](https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json)이다. 앱은 `MealRepository`를 통해 UTF-8 JSON을 읽고 `MealSnapshot`·`DailyMeals`로 검증한다. 수집기는 독립적으로 운영한다.
- 한국 날짜는 `KoreaDate`로 계산한다. 시각을 UTC+09:00 기준 날짜로 변환한 후 달력 날짜끼리 이동한다. 메뉴 미등록과 날짜 미포함을 구분한다.
- `MealController`(ChangeNotifier)가 유효한 캐시를 먼저 표시하고 중복 요청을 합친다. 검증한 응답은 빈 스냅샷도 포함해 전체 교체하고 `SharedPreferencesAsync`에 저장한다. 잘못된 응답은 캐시를 보존하고, 저장 실패 시에도 원격 데이터를 표시한다.
- 사용자가 Phase 3 정적 분석 및 Flutter 테스트 13개 통과, 실제 Chrome 원격 데이터·날짜 이동·갱신·오프라인 캐싱을 확인했다.

## Phase 4 화면과 설정

오늘·급식표·설정 탭은 같은 `MealController`를 사용한다. 오늘은 모바일 세로·넓은 화면 가로 식사 카드로 표시한다. 여러 날짜는 기간별 목록에서 펼치거나 날짜 상세로 이동한다. 한국 날짜가 바뀌면 오늘을 갱신한다.

설정 기본값은 시스템 테마, 회색 배경, 세 식사 모두, 전체 메뉴, 괄호 숨김 켜짐, 빈 날짜 숨김 꺼짐, 오늘부터 7일이다. 설정과 기간은 급식 캐시와 다른 키에 저장한다. 특식·대표 메뉴·괄호 가공은 표시 계층에서만 수행한다. 달력의 활성 여부는 원본 전체 식사를 기준으로 하며 오늘은 예외다. 빈 날짜 숨김은 급식표 탭에서만 선택 식사에 적용한다.

`app/`에서 `flutter analyze --no-pub` 통과 후 `flutter test --no-pub`를 실행하고 `flutter run -d chrome --no-pub`로 확인한다. 실제 UI의 좁은 폭·다크 모드·오프라인·재실행 설정 복원을 검증한다.

Phase 4 최초 구현은 사용자가 중괄호 린트를 수정한 뒤 정적 분석과 Flutter 테스트 20/20개를 통과했다. Chrome에서 모바일·데스크톱 크기의 오늘·급식표·설정·캘린더 화면을 확인했다.

Phase 4-2에서는 표시 계층에서 첫 실제 항목의 메뉴 줄을 판별하고 공통 테마의 대표 메뉴 스타일을 사용한다. 특식 안내는 별도 스타일을 유지한다. 급식표 접힘 행은 식사 아이콘·이름·대표 메뉴를 함께 표시하며 추가 메뉴가 있으면 해당 행에서 펼친다. 오늘 카드와 설정 간격 및 날짜 제목 폭을 조정했다. 테스트는 21개이며 최종 분석·테스트·Chrome 검증 결과는 미확인이다.

## Phase 5-1 웹 배포

- `.github/workflows/deploy-web.yml`은 `main`의 `app/**` 또는 워크플로 자체가 변경될 때 실행한다. 수동 배포는 **Actions → Deploy Flutter Web → Run workflow → main**에서 실행한다. 저장소 관리자가 **Settings → Pages → Source → GitHub Actions**를 설정한다.
- Ubuntu 빌드 작업은 Flutter 3.32.8 stable과 `app/pubspec.lock`을 사용한다. `--base-href /geubsik/`로 빌드하며 원본 HTML에는 Flutter 플레이스홀더를 유지한다. 빌드 결과 검사 후 `app/build/web`만 artifact로 전달하고 배포 작업이 `github-pages`에 게시한다. 빌드 결과물은 커밋하지 않는다. [예정 사이트](https://wkreho.github.io/geubsik/)
- 급식 수집 워크플로·외부 예약과 웹 배포를 독립적으로 유지한다. 앱은 기존 Raw URL로 데이터를 조회한다. `--pwa-strategy=none`을 사용하며 실행 중 급식 캐시와 오프라인 웹 시작을 구분한다. Pages와 Raw의 HTTP 캐시로 변경 반영이 늦어질 수 있다.
- Phase 5-1은 워크플로 구현 단계로 실제 release 빌드·Pages 배포·사이트 로딩은 미검증이다. Android APK·iOS 배포는 후속 단계다.

## 협업

일반 ChatGPT는 기획·요구사항·기술 검토·프롬프트 작성·결과 검토를 맡고 Codex는 로컬 구현·파일 관리·검증·결과 보고를 맡는다. 해당 단계에 필요한 파일만 확인하고 기존 사용자 작업을 보존한다. 앱 기능이나 미정인 배포 방식을 임의로 확정하지 않는다.

작업당 전체 오프라인 테스트는 최대 1회 실행한다. 모두 통과한 경우에만 실제 수집을 최대 1회 실행한다. 실패하면 원인·관련 파일·가능한 조치를 보고하고 다음 요청을 기다린다. 전체 코드·JSON·긴 로그 대신 파일 역할, 집계, 미검증 사항을 간단히 보고한다.
