"""Carrying hand-written Reason / Notes text over from a previous report."""

import sys
from dataclasses import dataclass, field
from pathlib import Path

REASON_HEADER = "Reason (fill in)"
NOTES_LABEL = "Notes"


@dataclass
class PreviousNotes:
    reasons: dict[tuple[str, str], str] = field(default_factory=dict)  # (sheet, alg) -> text
    notes: dict[str, str] = field(default_factory=dict)  # sheet -> text


def read_previous_notes(path: Path) -> PreviousNotes:
    prev = PreviousNotes()
    if not path.exists():
        return prev
    try:
        import openpyxl
        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    except Exception as e:  # corrupt / open in Excel / not an xlsx
        print(f"warning: could not read previous notes from {path}: {e}", file=sys.stderr)
        return prev

    for ws in wb.worksheets:
        rows = [list(r) for r in ws.iter_rows(values_only=True)]
        for r, row in enumerate(rows):
            for c, value in enumerate(row):
                if value == NOTES_LABEL and r + 1 < len(rows):
                    text = rows[r + 1][c] if c < len(rows[r + 1]) else None
                    if text:
                        prev.notes[ws.title] = str(text)
                elif value == REASON_HEADER:
                    for below in rows[r + 1:]:
                        alg = below[0] if below else None
                        if not alg:
                            break
                        text = below[c] if c < len(below) else None
                        if text:
                            prev.reasons[(ws.title, str(alg))] = str(text)
    wb.close()
    return prev
