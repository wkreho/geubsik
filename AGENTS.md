# 급식 작업 지침

프로젝트 루트는 `C:\Users\SEC\Documents\GitHub\geubsik`이며 현재 브랜치는 `main`이다. [GitHub 저장소](https://github.com/wkreho/geubsik)

한동글로벌학교 학생이 한국 시각 기준 오늘 급식을 빠르게 볼 수 있도록 한다. 학교의 기존 입력 흐름만 사용하고 학생·운영자에게 메뉴 재입력을 요구하지 않는다.

## 현재 구현

Phase 1은 scripts/fetch_meals.py, tests/test_fetch_meals.py 및 .github/workflows/update-meals.yml에 들어 있다. Python 3.12가 공개 XLSX를 인증 없이 읽고 openpyxl로 분석한다. 결과 파일 data/meals.json은 정상 수집 시 생성한다. 워크플로는 UTC 매시 7분·37분 또는 수동으로 실행하며 변경된 JSON만 기본 토큰으로 푸시한다. 로컬 구현과 실제 GitHub 실행·Pages 배포를 구분한다.

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

Phase 2에서 학교의 자동 추출·공개 재배포 허용을 확인했다. GitHub Actions 수동 실행으로 GitHub 서버의 실제 다운로드·파싱, 최초 JSON 생성, 자동 커밋·푸시(`99e848d`)를 검증했다. 사용자 브라우저에서 Raw JSON 접근에 성공했다. 30분 주기 예약은 설정했으며 실제 예약 실행 기록은 미확인이다. GitHub Pages는 미설정이다.

## Phase 3 앱 구현

- 기존 `app/`의 Android·iOS·Web 프로젝트를 사용한다. Flutter 3.32.8, Dart 3.8.1, http 1.6.0, shared_preferences 2.5.3, flutter_lints 5.0.0 및 SDK의 flutter_test를 기준으로 한다.
- 공통 데이터 URL은 [GitHub Raw 급식표](https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json)이다. 앱은 `MealRepository`를 통해 UTF-8 JSON을 읽고 `MealSnapshot`·`DailyMeals`로 검증한다. 수집기는 독립적으로 운영한다.
- 한국 날짜는 `KoreaDate`로 계산한다. 시각을 UTC+09:00 기준 날짜로 변환한 후 달력 날짜끼리 이동한다. 메뉴 미등록과 날짜 미포함을 구분한다.
- `MealController`(ChangeNotifier)가 유효한 캐시를 먼저 표시하고 중복 요청을 합친다. 검증한 응답은 빈 스냅샷도 포함해 전체 교체하고 `SharedPreferencesAsync`에 저장한다. 잘못된 응답은 캐시를 보존하고, 저장 실패 시에도 원격 데이터를 표시한다.
- 임시 화면과 오프라인 테스트를 구현했다. `app/`에서 `flutter analyze --no-pub`, `flutter test --no-pub`로 검증하고 `flutter run -d chrome --no-pub`로 실행한다. 실제 Flutter Web CORS·브라우저 캐시 동작은 별도 확인한다.

2026-11-26 Phase 3 코드는 작성·포맷했다. Codex 환경에서 Flutter 시작 스크립트가 쓰는 SDK 캐시 잠금 파일은 쓰기 허용 범위 밖에 있다. 정적 분석 명령은 결과 없이 중단했으며 전체 Flutter 테스트는 실행하지 않았다. 사용자 PowerShell 검증 결과를 받으면 갱신한다.

## 이후 개발 방향

Phase 4에서 최종 UI를 구현한다. 메인 화면은 오늘 표시, 날짜·요일, 이전/다음 화살표와 달력 선택, 아침·점심·저녁 아이콘과 카드, 미등록 안내와 마지막 갱신 시각을 담는다. 하단 탭은 ‘오늘’과 ‘급식표’ 두 개다. 설정 탭은 만들지 않는다. 급식표는 여러 날을 세로로 보여 주며 조회 범위는 미정이다.

Flutter Web 빌드·Pages 배포와 브라우저 캐시 정책을 후속 단계에서 검증한다. GITHUB_TOKEN 커밋에 의존하는 후속 push 워크플로·브랜치 기반 Pages 빌드는 실행되지 않을 수 있다. 예약 수집도 지연·비활성화될 수 있다.

## 협업

일반 ChatGPT는 기획·요구사항·기술 검토·프롬프트 작성·결과 검토를 맡고 Codex는 로컬 구현·파일 관리·검증·결과 보고를 맡는다. 해당 단계에 필요한 파일만 확인하고 기존 사용자 작업을 보존한다. 앱 기능이나 미정인 배포 방식을 임의로 확정하지 않는다.

작업당 전체 오프라인 테스트는 최대 1회 실행한다. 모두 통과한 경우에만 실제 수집을 최대 1회 실행한다. 실패하면 원인·관련 파일·가능한 조치를 보고하고 다음 요청을 기다린다. 전체 코드·JSON·긴 로그 대신 파일 역할, 집계, 미검증 사항을 간단히 보고한다.
