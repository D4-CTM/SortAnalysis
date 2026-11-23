"""The Summary worksheet comparing every dataset size."""

from typing import TYPE_CHECKING

from xlsxwriter.utility import xl_col_to_name, xl_rowcol_to_cell

from .notes import NOTES_LABEL
from .parsing import Dataset
from .stats import AlgStats
from .xlutil import SUMMARY_SHEET, quote, ref

if TYPE_CHECKING:
    from .report import Report


def write_summary_sheet(report: "Report", ws, datasets: list[Dataset], names: dict[int, str],
                        all_stats: dict[int, list[AlgStats]],
                        mean_pos: dict[int, dict[str, tuple[int, int]]],
                        sources: list[tuple[str, int]]):
    ws.activate()
    f = report.f
    algs = report.algorithms
    sizes = [d.size for d in datasets]

    ws.set_column(0, 0, 22)
    ws.set_column(1, len(sizes) + 1, 15)
    ws.write(0, 0, "Sorting algorithms benchmark", f["title"])
    ws.write(1, 0, f"{sum(len(d.runs) for d in datasets)} runs, {len(sizes)} dataset sizes, "
                   f"{len(sources)} CSV file(s)", f["subtitle"])

    def matrix(top: int, title: str, cell):
        ws.write(top, 0, title, f["section"])
        ws.write(top + 1, 0, "Algorithm", f["header"])
        for j, size in enumerate(sizes):
            ws.write(top + 1, 1 + j, names[size], f["header"])
        for i, alg in enumerate(algs):
            r = top + 2 + i
            ws.write(r, 0, alg, f["bold"])
            for j, size in enumerate(sizes):
                cell(r, 1 + j, size, next(s for s in all_stats[size] if s.name == alg))
        return top + 2 + len(algs)

    # Element counts row so the scaling chart has a numeric X axis.
    size_row = 3
    ws.write(size_row, 0, "Elements", f["header"])
    for j, size in enumerate(sizes):
        ws.write_number(size_row, 1 + j, size, f["int"])

    mean_top = size_row + 2
    best = {size: min((s.mean for s in all_stats[size] if s.ok), default=None) for size in sizes}

    def mean_cell(r, c, size, s: AlgStats):
        if not s.ok:
            ws.write_blank(r, c, None, f["skipped"])
            return
        ws.write_formula(r, c, f"={ref(names[size], *mean_pos[size][s.name])}",
                         f["best"] if s.mean == best[size] else f["ms_dec"], s.mean)

    mean_end = matrix(mean_top, "Mean time per dataset size (grey = skipped)", mean_cell)

    def ratio_cell(r, c, size, s: AlgStats):
        if not s.ok:
            ws.write_blank(r, c, None, f["skipped"])
            return
        col = xl_col_to_name(c)
        first, last = mean_top + 3, mean_top + 2 + len(algs)
        mean_ref = xl_rowcol_to_cell(mean_top + 2 + algs.index(s.name), c)
        ws.write_formula(r, c, f"={mean_ref}/MIN({col}{first}:{col}{last})", f["ratio"],
                         s.mean / best[size])

    ratio_top = mean_end + 1
    ratio_end = matrix(ratio_top, "Relative to fastest at each size (1.00x = fastest)", ratio_cell)

    fastest_top = ratio_end + 1
    ws.write(fastest_top, 0, "Fastest per size", f["section"])
    for c, h in enumerate(["Size", "Elements", "Fastest", "Mean", "Runs"]):
        ws.write(fastest_top + 1, c, h, f["header"])
    for i, d in enumerate(datasets):
        r = fastest_top + 2 + i
        ok = [s for s in all_stats[d.size] if s.ok]
        ws.write_url(r, 0, f"internal:{quote(names[d.size])}!A1", string=names[d.size])
        ws.write_number(r, 1, d.size, f["int"])
        if ok:
            w = min(ok, key=lambda s: s.mean)
            ws.write(r, 2, w.name, f["bold"])
            ws.write_number(r, 3, w.mean, f["ms_dec"])
        else:
            ws.merge_range(r, 2, r, 3, "everything skipped", f["skipped_label"])
        ws.write_number(r, 4, len(d.runs), f["int"])

    src_top = fastest_top + 2 + len(datasets) + 1
    ws.write(src_top, 0, "Source files", f["section"])
    ws.write(src_top + 1, 0, "File", f["header"])
    ws.write(src_top + 1, 1, "Rows", f["header"])
    for i, (src, rows) in enumerate(sources):
        ws.write(src_top + 2 + i, 0, src, f["text"])
        ws.write_number(src_top + 2 + i, 1, rows, f["int"])
    ws.set_column(0, 0, max(22, max((len(s) for s, _ in sources), default=0) + 2))

    notes_top = src_top + 2 + len(sources) + 1
    ws.write(notes_top, 0, NOTES_LABEL, f["section"])
    ws.merge_range(notes_top + 1, 0, notes_top + 6, max(len(sizes), 4),
                   report.prev.notes.get(SUMMARY_SHEET, ""), f["notes"])

    # Scaling chart: time vs elements, log-log so all sizes are readable.
    chart_col = len(sizes) + 3
    scaling = report.wb.add_chart({"type": "scatter", "subtype": "straight_with_markers"})
    for i, alg in enumerate(algs):
        if not any(next(s for s in all_stats[size] if s.name == alg).ok for size in sizes):
            continue
        r = mean_top + 2 + i
        color = report.colors[alg]
        scaling.add_series({
            "name": ref(SUMMARY_SHEET, r, 0),
            "categories": ref(SUMMARY_SHEET, size_row, 1, size_row, len(sizes)),
            "values": ref(SUMMARY_SHEET, r, 1, r, len(sizes)),
            "line": {"color": color, "width": 2},
            "marker": {"type": "circle", "size": 6, "fill": {"color": color}, "border": {"color": color}},
        })
    scaling.show_blanks_as("gap")
    scaling.set_title({"name": "Scaling: mean time vs dataset size (log-log)"})
    scaling.set_x_axis({"name": "Elements", "log_base": 10, "num_format": "#,##0",
                        "major_gridlines": {"visible": True}})
    scaling.set_y_axis({"name": "ms", "log_base": 10, "num_format": "#,##0",
                        "major_gridlines": {"visible": True}})
    scaling.set_legend({"position": "bottom"})
    scaling.set_size({"width": 820, "height": 440})
    ws.insert_chart(3, chart_col, scaling)

    # Grouped column chart: each size is a group, each algorithm a bar.
    grouped = report.wb.add_chart({"type": "column"})
    for i, alg in enumerate(algs):
        if not any(next(s for s in all_stats[size] if s.name == alg).ok for size in sizes):
            continue
        r = ratio_top + 2 + i
        grouped.add_series({
            "name": ref(SUMMARY_SHEET, r, 0),
            "categories": ref(SUMMARY_SHEET, mean_top + 1, 1, mean_top + 1, len(sizes)),
            "values": ref(SUMMARY_SHEET, r, 1, r, len(sizes)),
            "fill": {"color": report.colors[alg]},
        })
    grouped.set_title({"name": "How many times slower than the fastest (log scale)"})
    grouped.set_y_axis({"name": "x slower", "log_base": 10, "num_format": '0.0"x"',
                        "major_gridlines": {"visible": True}})
    grouped.set_legend({"position": "bottom"})
    grouped.set_size({"width": 820, "height": 400})
    ws.insert_chart(26, chart_col, grouped)
    ws.set_landscape()
    ws.fit_to_pages(1, 0)
