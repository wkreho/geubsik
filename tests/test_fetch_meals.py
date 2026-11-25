"""모든 워크북과 응답은 메모리 또는 테스트 임시 폴더에서 생성한다."""
import json
import os
import tempfile
import unittest
from datetime import date, datetime, timedelta
from email.message import Message
from io import BytesIO
from pathlib import Path
from unittest.mock import patch
from urllib.error import URLError
from zipfile import ZipFile

from openpyxl import Workbook
from openpyxl.utils.datetime import CALENDAR_MAC_1904, to_excel

from scripts import fetch_meals as f


MONDAY = date(2020, 12, 28)
NOTE = "※ 메뉴는 식자재 수급 상황 등에 따라 일부 변경될 수 있습니다."


def add_week(book, name, start):
    ws = book.create_sheet(name)
    ws["C1"] = "한동글로벌학교 주간 식단표"
    ws["A2"], ws["B2"], ws["A3"] = "Week of", start, "구분"
    for i, weekday in enumerate(f.WEEKDAYS):
        day = start + timedelta(days=i)
        ws.cell(3, i + 2, f"{day.month}/{day.day}")
        ws.cell(4, i + 2, weekday)
    ws["A5"], ws["A14"], ws["A22"] = "조식", "중식", "석식"
    ws["A30"] = "▪상기 메뉴의 원산지와 확정 메뉴는 식당 내 당일 게시메뉴에 표시되어있습니다."
    ws["A31"] = "▪메뉴는 식자재 수급 상황 등에 따라 일부 변경될 수 있습니다."
    ws["A32"] = (
        "▪특정 식품 알러지가 있는 학생은 메뉴선택시 매니저(영양사)에게 문의해주시기 바랍니다.\n"
        "1난류, 2우유, 3메밀, 4땅콩,5대두,6밀,7고등어,8게,9새우,10돼지고기,"
        "11복숭아,12토마토, 13아황산염, 14호두, 15닭고기,16소고기, 17오징어, 18조개류(굴, 전복, 홍합 포함), 19잣"
    )
    return ws


def workbook():
    book = Workbook()
    book.remove(book.active)
    return book, add_week(book, "띄 어쓰기 09월!", MONDAY)


def archive(book):
    buf = BytesIO()
    book.save(buf)
    return buf.getvalue()


class Parsing(unittest.TestCase):
    def test_week_meals_order_and_text(self):
        book, ws = workbook()
        dishes = ["한그릇(돈육:국산),소스/밥 & 빵(12)", "<특식>\n닭구이\n옥수수", "김치", "김치"]
        ws["B5"], ws["B7"] = "  " + dishes[0] + " ", " \r\n<특식>\r닭구이\r\n옥수수 \t"
        ws["B8"], ws["B9"], ws["B10"] = " ", dishes[2], dishes[3]
        ws["B14"], ws["C22"] = "중식", "석식"
        ws["C28"] = "배"
        # A30에서 석식이 끝난다. 다음 행의 날짜 열에 음식명이 있어도 제외해야 한다.
        ws["C31"] = "사과"
        ws["C32"] = "1난류, 2우유, 3메밀"
        meals, _ = f.parse_workbook(book)
        self.assertEqual(list(meals), [(MONDAY + timedelta(days=i)).isoformat() for i in range(7)])
        self.assertEqual(meals["2020-12-28"], dict(breakfast=dishes, lunch=["중식"], dinner=[]))
        self.assertEqual(meals["2020-12-29"], dict(breakfast=[], lunch=[], dinner=["석식", "배"]))
        for key in ("2021-01-02", "2021-01-03"):
            self.assertEqual(meals[key], dict(breakfast=[], lunch=[], dinner=[]))
        self.assertNotIn(NOTE, str(meals))
        self.assertNotIn("난류", str(meals))

    def test_notice_in_date_column(self):
        book, ws = workbook()
        for row in range(30, 33):
            ws.cell(row, 1).value = None
        ws["B28"], ws["B30"], ws["B31"] = "사과", NOTE, "① 난류 ② 우유"
        meals, _ = f.parse_workbook(book)
        self.assertEqual(meals[MONDAY.isoformat()]["dinner"], ["사과"])

    def test_hidden_blank_unrelated_and_no_visible(self):
        book, ws = workbook()
        ws["B5"] = "밥"
        for state in ("hidden", "veryHidden"):
            tab = book.create_sheet(state)
            tab["A2"] = "Week of"  # 방문하면 구조 오류가 발생한다.
            tab.sheet_state = state
        add_week(book, "다음 양식", MONDAY + timedelta(days=7))
        book.create_sheet("연락처")["A1"] = "담당 부서"
        restored = f.open_xlsx(archive(book))
        try:
            meals, stats = f.parse_workbook(restored)
        finally:
            restored.close()
        self.assertEqual(len(meals), 7)
        self.assertEqual(stats, dict(total=5, visible=3, hidden=2, unrelated=1, empty=1, included=1))
        for tab in book.worksheets:
            tab.sheet_state = "hidden"
        with self.assertRaisesRegex(ValueError, "표시 상태"):
            f.parse_workbook(book)

    def test_mixed_date_formats_and_epoch(self):
        for epoch in (Workbook().epoch, CALENDAR_MAC_1904):
            for start in (MONDAY, datetime(2020, 12, 28), "12/28/2020", "2020-12-28", to_excel(MONDAY, epoch)):
                with self.subTest(epoch=epoch, start=start):
                    book, ws = workbook()
                    book.epoch = epoch
                    ws["B2"] = start
                    ws["B3"], ws["C3"], ws["D3"] = start, to_excel(MONDAY + timedelta(days=1), epoch), "12/30"
                    ws["B5"] = "밥"
                    meals, _ = f.parse_workbook(book)
                    self.assertIn("2021-01-03", meals)

    def test_damaged_structure(self):
        for cell, value in (("A2", None), ("B2", "invalid"), ("B2", date(2020, 12, 29)),
                            ("B3", "12/29"), ("B3", "12/28/2021"), ("C4", "Friday"),
                            ("A14", None), ("A18", "조식"), ("B14", NOTE), ("B29", "미확인 행")):
            with self.subTest(cell=cell, value=value):
                book, ws = workbook()
                ws[cell].value = value
                with self.assertRaises(ValueError):
                    f.parse_workbook(book)

    def test_moved_meal_rows(self):
        book, ws = workbook()
        ws.insert_rows(12, 2)
        ws["B13"], ws["B16"], ws["B24"] = "마지막 조식", "점심", "저녁"
        meals, _ = f.parse_workbook(book)
        self.assertEqual(meals[MONDAY.isoformat()],
                         dict(breakfast=["마지막 조식"], lunch=["점심"], dinner=["저녁"]))

    def test_overlapping_weeks_including_blank(self):
        book, ws = workbook()
        ws["B5"] = "밥"
        add_week(book, "중복", MONDAY)
        with self.assertRaisesRegex(ValueError, "날짜 중복"):
            f.parse_workbook(book)

    def test_non_weekly_only_is_failure(self):
        with self.assertRaisesRegex(ValueError, "주간 급식표"):
            f.parse_workbook(Workbook())

    def test_xlsx_response_validation(self):
        buf = BytesIO()
        with ZipFile(buf, "w") as z:
            z.writestr("other.txt", "not a workbook")
        for payload in (b"", b"<html>login</html>", buf.getvalue()):
            with self.subTest(size=len(payload)), self.assertRaises(ValueError):
                f.open_xlsx(payload)
        response = BytesIO(b"<html>login</html>")
        response.status = 200
        response.headers = Message()
        response.headers["Content-Type"] = "text/html; charset=UTF-8"
        with patch.object(f, "urlopen", return_value=response), self.assertRaisesRegex(ValueError, "HTML"):
            f.download_xlsx()


class Snapshots(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / "data" / "meals.json"
        self.book, self.ws = workbook()
        self.ws["B5"], self.ws["B6"] = "밥", "김치"

    def save(self, allow_empty=False):
        meals, _ = f.parse_workbook(self.book)
        return f.update_snapshot(self.path, meals, allow_empty)

    def read(self):
        return json.loads(self.path.read_text(encoding="utf-8"))

    def test_create_change_delete_and_noop(self):
        self.save()
        raw = self.path.read_bytes()
        first = self.read()
        self.assertIn("밥".encode(), raw)
        self.assertTrue(raw.endswith(b"\n"))
        self.assertIn(b'\n  "schemaVersion": 1,', raw)
        self.assertTrue(first["updatedAt"].endswith("+09:00"))
        os.utime(self.path, (1000000000, 1000000000))
        before = self.path.stat().st_mtime_ns
        with patch.object(f.os, "replace", side_effect=AssertionError("불필요한 재작성")):
            self.save()
        self.assertEqual(self.path.read_bytes(), raw)
        self.assertEqual(self.path.stat().st_mtime_ns, before)
        # 시계 정밀도와 무관하게 변경 시각 갱신을 확인한다.
        first["updatedAt"] = "2001-01-01T00:00:00+09:00"
        self.path.write_text(json.dumps(first), encoding="utf-8")
        self.ws["B5"], self.ws["B6"].value = "잡곡밥", None
        self.save()
        changed = self.read()
        self.assertNotEqual(changed["updatedAt"], first["updatedAt"])
        self.assertEqual(changed["meals"][MONDAY.isoformat()]["breakfast"], ["잡곡밥"])

    def test_week_removal_and_restore(self):
        other = add_week(self.book, "별도 주", MONDAY + timedelta(days=7))
        other["H28"] = "사과"
        self.save()
        self.assertEqual(len(self.read()["meals"]), 14)
        for action in ("hidden", "visible", "blank", "refill", "delete"):
            with self.subTest(action=action):
                if action == "delete":
                    self.book.remove(other)
                elif action in ("hidden", "visible"):
                    other.sheet_state = action
                else:
                    other["H28"].value = None if action == "blank" else "배"
                self.save()
                self.assertEqual(len(self.read()["meals"]), 14 if action in ("visible", "refill") else 7)

    def test_download_and_parse_failures_preserve_file(self):
        self.save()
        before = self.path.read_bytes()
        damaged = add_week(self.book, "불완전 주", MONDAY + timedelta(days=7))
        damaged["B2"].value = None
        for error, payload in ((URLError("offline"), b""), (None, b"html"), (None, archive(self.book))):
            with self.subTest(error=error, size=len(payload)):
                with patch.object(f, "download_xlsx", side_effect=error, return_value=payload):
                    with self.assertRaises((ValueError, URLError)):
                        f.run(self.path, allow_empty=True)
                self.assertEqual(self.path.read_bytes(), before)

    def test_empty_guard_and_explicit_override(self):
        self.save()
        before = self.path.read_bytes()
        self.ws["B5"].value = self.ws["B6"].value = None
        with self.assertRaisesRegex(ValueError, "--allow-empty"):
            self.save()
        self.assertEqual(self.path.read_bytes(), before)
        self.save(allow_empty=True)
        self.assertEqual(self.read()["meals"], {})

    def test_invalid_old_json_preserved(self):
        self.save()
        for invalid in ('{', '{"meals": {}, "meals": {}}', '{}'):
            self.path.write_text(invalid, encoding="utf-8")
            with self.subTest(invalid=invalid), self.assertRaisesRegex(ValueError, "기존 JSON"):
                self.save()
            self.assertEqual(self.path.read_text(encoding="utf-8"), invalid)

    def test_atomic_replace_failure(self):
        self.save()
        before = self.path.read_bytes()
        self.ws["B5"] = "다른 밥"
        with patch.object(f.os, "replace", side_effect=OSError("busy")), self.assertRaises(OSError):
            self.save()
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(self.path.parent.glob("*.tmp")), [])

    def test_schema_rejects_malformed_data(self):
        self.save()
        for field, value in (("schemaVersion", True), ("updatedAt", "2020-01-01"),
                             ("meals", []), ("meals", {"2020-1-1": {}}),
                             ("meals", {"2020-01-01": {"breakfast": []}})):
            doc = self.read()
            doc[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                f.validate_snapshot(doc)
        for invalid in (None, "밥", [1], [""], ["\r"], [NOTE]):
            doc = self.read()
            doc["meals"][MONDAY.isoformat()]["breakfast"] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                f.validate_snapshot(doc)


if __name__ == "__main__":
    unittest.main()
