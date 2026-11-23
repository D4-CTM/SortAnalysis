"""Sheet naming and cell-reference helpers."""

from xlsxwriter.utility import xl_rowcol_to_cell

SUMMARY_SHEET = "Summary"


def human_size(n: int) -> str:
    for div, suffix in ((1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")):
        if n >= div:
            value = n / div
            text = f"{value:.0f}" if value == int(value) else f"{value:.2f}".rstrip("0").rstrip(".")
            return text + suffix
    return str(n)


def sheet_names(sizes: list[int]) -> dict[int, str]:
    names: dict[int, str] = {}
    used = {SUMMARY_SHEET}
    for size in sizes:
        name = human_size(size)
        if name in used:  # e.g. two sizes that both round to 1.87B
            name = str(size)
        used.add(name)
        names[size] = name
    return names


def quote(sheet: str) -> str:
    return "'" + sheet.replace("'", "''") + "'"


def ref(sheet: str, row: int, col: int, row2: int | None = None, col2: int | None = None) -> str:
    a = xl_rowcol_to_cell(row, col, row_abs=True, col_abs=True)
    if row2 is None:
        return f"{quote(sheet)}!{a}"
    b = xl_rowcol_to_cell(row2, col2, row_abs=True, col_abs=True)
    return f"{quote(sheet)}!{a}:{b}"
