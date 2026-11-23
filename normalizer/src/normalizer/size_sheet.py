"""One worksheet per dataset size: stats, skipped runs, notes, raw runs, charts."""

from typing import TYPE_CHECKING

from xlsxwriter.utility import xl_col_to_name, xl_rowcol_to_cell

from .notes import NOTES_LABEL, REASON_HEADER
from .parsing import Dataset
from .stats import AlgStats, compute_stats
from .stats import ranked as rank
from .xlutil import human_size, ref

if TYPE_CHECKING:
    from .report import Report


def write_size_sheet(report: "Report", name: str, ds: Dataset) -> tuple[list[AlgStats], dict[str, tuple[int, int]]]:
    """Writes one dataset sheet; returns its stats and the (row, col) of each mean cell."""
    ws = report.wb.add_worksheet(name)
    f = report.f
    stats = compute_stats(ds, report.algorithms)
    # Fully skipped algorithms go last so chart ranges stay contiguous.
    ranked = rank(stats)
    measured = [s for s in ranked if s.ok]
    partial_or_skipped = [s for s in stats if s.skipped]
    n_runs = len(ds.runs)
    sources = sorted({r.source for r in ds.runs})

    ws.set_column(0, 0, 22)
    ws.set_column(1, 11, 14)
    ws.write(0, 0, f"Dataset size: {ds.size:,} elements", f["title"])
    ws.write(1, 0, f"{n_runs} run(s) from {len(sources)} file(s): {', '.join(sources)}", f["subtitle"])

    # Layout (rows): stats table, skipped table, notes, raw data.
    stats_top = 3
    stats_hdr = stats_top + 1
    stats_first = stats_hdr + 1
    stats_last = stats_first + len(ranked) - 1

    skip_top = stats_last + 2
    skip_rows = max(len(partial_or_skipped), 1)
    notes_top = skip_top + 2 + skip_rows + 1
    notes_height = 5
    raw_top = notes_top + 1 + notes_height + 1
    raw_hdr = raw_top + 1
    raw_first = raw_hdr + 1
    raw_last = raw_first + n_runs - 1
    raw_alg_col = {alg: 3 + i for i, alg in enumerate(report.algorithms)}

    # Raw data ----------------------------------------------------------- #
    ws.write(raw_top, 0, "Raw runs", f["section"])
    ws.write(raw_top, 3, "grey cells = skipped execution", f["hint"])
    for c, h in enumerate(["Source file", "Run #", "Iteration",
                           *[f"{a} (ms)" for a in report.algorithms]]):
        ws.write(raw_hdr, c, h, f["header"])
    for i, run in enumerate(ds.runs):
        r = raw_first + i
        ws.write(r, 0, run.source, f["text"])
        ws.write(r, 1, i + 1, f["int"])
        ws.write(r, 2, run.iteration, f["int"])
        for alg, c in raw_alg_col.items():
            v = run.times.get(alg)
            if v is None:
                ws.write_blank(r, c, None, f["skipped"])
            else:
                ws.write_number(r, c, v, f["ms"])

    # Statistics --------------------------------------------------------- #
    ws.write(stats_top, 0, "Performance (sorted fastest → slowest)", f["section"])
    headers = ["Algorithm", "Runs measured", "Runs skipped", "Min", "Max", "Mean",
               "Median", "Std dev", "Throughput (M elem/s)", "vs fastest", "Rank"]
    for c, h in enumerate(headers):
        ws.write(stats_hdr, c, h, f["header"])
    ws.set_row(stats_hdr, 30)

    best_mean = measured[0].mean if measured else None
    mean_col_range = ref(name, stats_first, 5, stats_last, 5)
    for i, s in enumerate(ranked):
        r = stats_first + i
        col = xl_col_to_name(raw_alg_col[s.name])
        rng = f"{col}{raw_first + 1}:{col}{raw_last + 1}"
        mean_cell = xl_rowcol_to_cell(r, 5)
        ws.write(r, 0, s.name, f["bold"])
        ws.write_formula(r, 1, f"=COUNT({rng})", f["int"], len(s.values))
        ws.write_formula(r, 2, f"=ROWS({rng})-COUNT({rng})", f["int"], s.skipped)
        if not s.ok:
            ws.merge_range(r, 3, r, 10, "skipped in every run", f["skipped_label"])
            continue
        ws.write_formula(r, 3, f"=MIN({rng})", f["ms"], min(s.values))
        ws.write_formula(r, 4, f"=MAX({rng})", f["ms"], max(s.values))
        ws.write_formula(r, 5, f"=AVERAGE({rng})", f["best"] if i == 0 else f["ms_dec"], s.mean)
        ws.write_formula(r, 6, f"=MEDIAN({rng})", f["ms_dec"], s.median)
        ws.write_formula(r, 7, f'=IF(COUNT({rng})>1,STDEV({rng}),"")', f["ms_dec"],
                         s.stdev if s.stdev is not None else "")
        ws.write_formula(r, 8, f"={ds.size}/{mean_cell}/1000", f["tput"], ds.size / s.mean / 1000)
        ws.write_formula(r, 9, f"={mean_cell}/MIN({mean_col_range})", f["ratio"], s.mean / best_mean)
        ws.write_formula(r, 10, f"=RANK({mean_cell},{mean_col_range},1)", f["int"], i + 1)

    # Skipped executions ------------------------------------------------- #
    ws.write(skip_top, 0, "Skipped executions", f["section"])
    for c, h in enumerate(["Algorithm", "Skipped", "Of runs"]):
        ws.write(skip_top + 1, c, h, f["header"])
    ws.merge_range(skip_top + 1, 3, skip_top + 1, 10, REASON_HEADER, f["header"])
    if not partial_or_skipped:
        ws.merge_range(skip_top + 2, 0, skip_top + 2, 10,
                       "No skipped executions for this dataset size.", f["hint"])
    for i, s in enumerate(partial_or_skipped):
        r = skip_top + 2 + i
        ws.write(r, 0, s.name, f["bold"])
        ws.write(r, 1, s.skipped, f["int"])
        ws.write(r, 2, n_runs, f["int"])
        ws.merge_range(r, 3, r, 10, report.prev.reasons.get((name, s.name), ""), f["reason"])
        ws.set_row(r, 32)

    # Notes -------------------------------------------------------------- #
    ws.write(notes_top, 0, NOTES_LABEL, f["section"])
    ws.merge_range(notes_top + 1, 0, notes_top + notes_height, 10,
                   report.prev.notes.get(name, ""), f["notes"])

    # Charts ------------------------------------------------------------- #
    chart_col = 12
    if measured:
        last_ok = stats_first + len(measured) - 1
        cats = ref(name, stats_first, 0, last_ok, 0)
        spread = max(s.mean for s in measured) / min(s.mean for s in measured)
        log = spread >= 100

        bar = report.wb.add_chart({"type": "column"})
        bar.add_series({
            "name": "Mean time",
            "categories": cats,
            "values": ref(name, stats_first, 5, last_ok, 5),
            "points": [{"fill": {"color": report.colors[s.name]}} for s in measured],
            "data_labels": {"value": True, "num_format": "#,##0"},
            **({"y_error_bars": {"type": "custom",
                                 "plus_values": ref(name, stats_first, 7, last_ok, 7),
                                 "minus_values": ref(name, stats_first, 7, last_ok, 7)}}
               if n_runs > 1 and not log else {}),
        })
        bar.set_title({"name": f"Mean sort time — {human_size(ds.size)} elements"})
        bar.set_y_axis({"name": "ms" + (" (log scale)" if log else ""),
                        "num_format": "#,##0", "major_gridlines": {"visible": True},
                        **({"log_base": 10} if log else {})})
        bar.set_legend({"none": True})
        bar.set_size({"width": 720, "height": 340})
        ws.insert_chart(stats_top, chart_col, bar)

        tput = report.wb.add_chart({"type": "bar"})
        tput.add_series({
            "name": "Throughput",
            "categories": cats,
            "values": ref(name, stats_first, 8, last_ok, 8),
            "points": [{"fill": {"color": report.colors[s.name]}} for s in measured],
            "data_labels": {"value": True, "num_format": "#,##0.00"},
        })
        tput.set_title({"name": "Throughput (million elements / second, higher is better)"})
        tput.set_x_axis({"num_format": "General", "major_gridlines": {"visible": True},
                         **({"log_base": 10} if log else {})})
        tput.set_y_axis({"reverse": True})
        tput.set_legend({"none": True})
        tput.set_size({"width": 720, "height": 300})
        ws.insert_chart(stats_top + 18, chart_col, tput)

        if n_runs > 1:
            line = report.wb.add_chart({"type": "line"})
            for s in measured:
                c = raw_alg_col[s.name]
                line.add_series({
                    "name": s.name,
                    "categories": ref(name, raw_first, 1, raw_last, 1),
                    "values": ref(name, raw_first, c, raw_last, c),
                    "line": {"color": report.colors[s.name], "width": 2},
                    "marker": {"type": "circle", "size": 4,
                               "fill": {"color": report.colors[s.name]},
                               "border": {"color": report.colors[s.name]}},
                })
            line.show_blanks_as("gap")
            line.set_title({"name": "Time per run (consistency across iterations)"})
            line.set_x_axis({"name": "Run #"})
            line.set_y_axis({"name": "ms" + (" (log scale)" if log else ""), "num_format": "#,##0",
                             **({"log_base": 10} if log else {})})
            line.set_legend({"position": "bottom"})
            line.set_size({"width": 720, "height": 340})
            ws.insert_chart(stats_top + 34, chart_col, line)

    ws.freeze_panes(stats_top, 0)
    ws.set_landscape()
    ws.fit_to_pages(1, 0)
    return stats, {s.name: (stats_first + i, 5) for i, s in enumerate(ranked)}
