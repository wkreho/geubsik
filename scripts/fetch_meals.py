"""학교 공개 XLSX의 표시된 주간 급식표를 하나의 JSON 스냅샷으로 저장한다."""
import argparse
import json
import os
import re
import sys
import tempfile
from contextlib import closing
from datetime import date, datetime, timedelta
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen
from zipfile import BadZipFile, ZipFile
from zoneinfo import ZoneInfo

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from openpyxl.utils.datetime import from_excel


EXPORT_URL = (
    "https://docs.google.com/spreadsheets/d/"
    "1-H15GqsbE3APbGec7rNbw7_Cvm1UBq4mQpVF-Nw_74c/export?format=xlsx"
)
OUTPUT = Path(__file__).resolve().parents[1] / "data" / "meals.json"
LABELS = {"조식": "breakfast", "중식": "lunch", "석식": "dinner"}
WEEKDAYS = "MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY SUNDAY".split()
NOTICE_MARKERS = (
    "상기메뉴의원산지", "식당내당일게시메뉴", "식자재수급상황",
    "특정식품알러지", "특정식품알레르기", "매니저(영양사)",
    "알레르기유발", "알러지유발", "알레르기번호", "알러지번호",
)


def download_xlsx():
    with urlopen(EXPORT_URL, timeout=30) as response:
        if response.status != 200:
            raise ValueError(f"XLSX 다운로드 HTTP {response.status}")
        if response.headers.get_content_type() in {"text/html", "application/xhtml+xml"}:
            raise ValueError("XLSX 대신 HTML 응답을 받았습니다. 원본 공유 상태를 확인하세요.")
        return response.read()


def open_xlsx(payload):
    stream = BytesIO(payload)
    try:
        with ZipFile(stream) as archive:
            if not {"[Content_Types].xml", "xl/workbook.xml"} <= set(archive.namelist()):
                raise ValueError("필수 XLSX 구성 파일이 없습니다.")
    except BadZipFile as exc:
        raise ValueError("응답이 정상적인 XLSX 압축 파일이 아닙니다.") from exc
    stream.seek(0)
    return load_workbook(stream, read_only=True, data_only=True)


def compact(value):
    return "".join(str(value or "").split())


def is_notice(value):
    return any(marker in compact(value) for marker in NOTICE_MARKERS)


def menu_text(value):
    if value is None:
        return ""
    if not isinstance(value, str):
        raise ValueError("메뉴 셀에 문자열 이외의 값이 있습니다.")
    return value.replace("\r\n", "\n").replace("\r", "\n").strip()


def cell_date(value, epoch, expected=None):
    if isinstance(value, datetime):
        return value.date()
    if type(value) is date:
        return value
    if type(value) in (int, float):
        converted = from_excel(value, epoch)
        if isinstance(converted, datetime):
            return converted.date()
    if isinstance(value, str):
        value = value.strip()
        if expected and re.fullmatch(r"\d{1,2}[./-]\d{1,2}", value):
            month, day = map(int, re.split(r"[./-]", value))
            return date(expected.year, month, day)
        for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d"):
            try:
                return datetime.strptime(value, fmt).date()
            except ValueError:
                continue
    raise ValueError("날짜 형식을 해석할 수 없습니다.")


def looks_weekly(rows):
    if not rows:
        return False
    top = rows[:4]
    markers = {compact(row[0]).lower() for row in top}
    return (
        "weekof" in markers
        or any("주간식단표" in compact(cell) for row in top for cell in row)
        or any(compact(row[0]) in LABELS for row in rows)
        or ("구분" in markers and any(compact(cell).upper() == "MONDAY" for row in top for cell in row))
    )


def week_dates(rows, epoch):
    if len(rows) < 4 or compact(rows[1][0]).lower() != "weekof" or compact(rows[2][0]) != "구분":
        raise ValueError("A2의 Week of 또는 A3의 구분을 확인하세요.")
    try:
        monday = cell_date(rows[1][1], epoch)
    except ValueError as exc:
        raise ValueError(f"B2 주간 시작일 오류: {exc}") from exc
    if monday.weekday() != 0:
        raise ValueError("B2 주간 시작일이 월요일이 아닙니다.")
    dates = []
    for offset, weekday in enumerate(WEEKDAYS):
        expected = monday + timedelta(days=offset)
        col = offset + 1
        letter = get_column_letter(col + 1)
        try:
            actual = cell_date(rows[2][col], epoch, expected)
        except ValueError as exc:
            raise ValueError(f"{letter}3 날짜 오류: {exc}") from exc
        if actual != expected:
            raise ValueError(f"{letter}3 날짜 불일치 (예상 {expected}, 원본 {actual})")
        if compact(rows[3][col]).upper().rstrip(".") not in {weekday, weekday[:3]}:
            raise ValueError(f"{letter}4 요일 불일치 (예상 {weekday})")
        dates.append(expected.isoformat())
    return dates


def meal_ranges(rows):
    starts = [(i, compact(row[0])) for i, row in enumerate(rows) if compact(row[0]) in LABELS]
    if [label for _, label in starts] != list(LABELS) or starts[0][0] < 4:
        raise ValueError("조식·중식·석식 구역의 순서, 누락 또는 중복을 확인하세요.")
    dinner = starts[-1][0]
    end = len(rows)
    for i in range(dinner + 1, len(rows)):
        row = rows[i]
        if any(is_notice(value) for value in row):
            if i < dinner + 7:
                raise ValueError(f"{i + 1}행의 석식 메뉴 영역에 공통 안내문이 있습니다.")
            if any(compact(value) and not is_notice(value) for value in row[1:]):
                raise ValueError(f"{i + 1}행에서 안내문과 다른 데이터가 섞여 있습니다.")
            end = i
            break
        if compact(row[0]) or (i >= dinner + 7 and any(compact(cell) for cell in row[1:])):
            raise ValueError(f"{i + 1}행의 석식 끝 또는 공통 안내문 경계를 확인하세요.")
    ends = [starts[1][0], dinner, end]
    return [(LABELS[label], start, stop) for (start, label), stop in zip(starts, ends)]


def parse_week(rows, epoch):
    dates = week_dates(rows, epoch)
    week = {day: {key: [] for key in LABELS.values()} for day in dates}
    for meal, start, end in meal_ranges(rows):
        for i in range(start, end):
            if i > start and compact(rows[i][0]):
                raise ValueError(f"A{i + 1}에 예상하지 못한 구분이 있습니다.")
            for col, day in enumerate(dates, start=1):
                item = menu_text(rows[i][col])
                if item:
                    if is_notice(item):
                        raise ValueError(f"{get_column_letter(col + 1)}{i + 1} 메뉴에 공통 안내문이 있습니다.")
                    week[day][meal].append(item)
    return week


def parse_workbook(book):
    sheets = book.worksheets
    visible = [ws for ws in sheets if ws.sheet_state == "visible"]
    stats = dict(total=len(sheets), visible=len(visible), hidden=len(sheets) - len(visible),
                 unrelated=0, empty=0, included=0)
    if not visible:
        raise ValueError("표시 상태인 워크시트가 없습니다.")
    seen = set()
    meals = {}
    for ws in visible:
        rows = [
            tuple(cell.value if cell.data_type != "e" else ValueError("Excel 셀 오류") for cell in row)
            for row in ws.iter_rows(max_col=8)
        ]
        if not looks_weekly(rows):
            stats["unrelated"] += 1
            continue
        try:
            week = parse_week(rows, book.epoch)
        except ValueError as exc:
            raise ValueError(f"표시 탭 {ws.title!r}: {exc}") from exc
        overlap = seen.intersection(week)
        if overlap:
            raise ValueError(f"표시된 주간 탭의 날짜 중복: {min(overlap)}")
        seen.update(week)
        if any(any(day.values()) for day in week.values()):
            meals.update(week)
            stats["included"] += 1
        else:
            stats["empty"] += 1
    if not seen:
        raise ValueError("검증할 수 있는 표시 주간 급식표가 없습니다.")
    return dict(sorted(meals.items())), stats


def validate_snapshot(doc):
    if not isinstance(doc, dict) or set(doc) != {"schemaVersion", "updatedAt", "meals"}:
        raise ValueError("JSON 최상위 필드가 스키마와 다릅니다.")
    if type(doc["schemaVersion"]) is not int or doc["schemaVersion"] != 1:
        raise ValueError("지원하지 않는 schemaVersion입니다.")
    stamp = doc["updatedAt"]
    if not isinstance(stamp, str) or "T" not in stamp or not stamp.endswith("+09:00"):
        raise ValueError("updatedAt은 UTC+09:00의 ISO 시각이어야 합니다.")
    datetime.fromisoformat(stamp)
    if not isinstance(doc["meals"], dict):
        raise ValueError("meals는 날짜별 객체여야 합니다.")
    for key, day in doc["meals"].items():
        if not isinstance(key, str) or date.fromisoformat(key).isoformat() != key:
            raise ValueError("날짜 키 형식이 잘못되었습니다.")
        if not isinstance(day, dict) or set(day) != set(LABELS.values()):
            raise ValueError(f"{key}의 식사 필드가 올바르지 않습니다.")
        for items in day.values():
            if not isinstance(items, list) or any(
                not isinstance(item, str) or not item or item != menu_text(item) or is_notice(item)
                for item in items
            ):
                raise ValueError(f"{key}에 유효하지 않은 메뉴 배열이 있습니다.")


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"기존 JSON에 중복 키가 있습니다: {key}")
        result[key] = value
    return result


def update_snapshot(path, meals, allow_empty=False):
    doc = {"schemaVersion": 1, "updatedAt": datetime.now(ZoneInfo("Asia/Seoul")).isoformat(),
           "meals": dict(sorted(meals.items()))}
    validate_snapshot(doc)
    if path.exists():
        try:
            old = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_keys)
            validate_snapshot(old)
        except ValueError as exc:
            raise ValueError(f"기존 JSON 손상 또는 미지원 형식. 파일을 보존합니다: {exc}") from exc
        if old["schemaVersion"] == doc["schemaVersion"] and old["meals"] == meals:
            return "변경 없음 (기존 파일 및 updatedAt 유지)"
        if old["meals"] and not meals and not allow_empty:
            raise ValueError("경고: 전체 빈 결과로 변경되어 기존 파일을 보존합니다. 확인 후 --allow-empty 사용")
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent,
                                         prefix=".meals-", suffix=".tmp", delete=False) as tmp:
            temp_path = Path(tmp.name)
            json.dump(doc, tmp, ensure_ascii=False, indent=2)
            tmp.write("\n")
            tmp.flush()
            os.fsync(tmp.fileno())
        os.replace(temp_path, path)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
    return "새 스냅샷 저장"


def run(path=OUTPUT, allow_empty=False):
    payload = download_xlsx()
    with closing(open_xlsx(payload)) as book:
        print("비인증 XLSX 다운로드 및 워크북 로딩 성공", flush=True)
        meals, stats = parse_workbook(book)
    print("탭 집계:", stats)
    days_with_menus = sum(any(day.values()) for day in meals.values())
    span = f"{min(meals)} ~ {max(meals)}" if meals else "없음"
    print(f"포함 날짜 {len(meals)}, 메뉴 있는 날짜 {days_with_menus}, 범위 {span}")
    print(update_snapshot(path, meals, allow_empty))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-empty", action="store_true", help="검증된 전체 빈 주간표로 기존 급식을 교체")
    args = parser.parse_args()
    try:
        run(allow_empty=args.allow_empty)
    except Exception as error:
        sys.exit(f"급식 갱신 실패 ({type(error).__name__}): {error}")
