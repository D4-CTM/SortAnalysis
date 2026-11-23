"""Builds the workbook: a Summary tab followed by one tab per dataset size."""

from pathlib import Path

import xlsxwriter

from .notes import PreviousNotes
from .parsing import Dataset
from .size_sheet import write_size_sheet
from .stats import AlgStats
from .styles import PALETTE, make_formats
from .summary_sheet import write_summary_sheet
from .xlutil import SUMMARY_SHEET, sheet_names


class Report:
    def __init__(self, path: Path, algorithms: list[str], prev: PreviousNotes):
        self.wb = xlsxwriter.Workbook(str(path))
        self.algorithms = algorithms
        self.colors = {a: PALETTE[i % len(PALETTE)] for i, a in enumerate(algorithms)}
        self.prev = prev
        self.f = make_formats(self.wb)

    def build(self, datasets: dict[int, Dataset], sources: list[tuple[str, int]]):
        ordered = [datasets[s] for s in sorted(datasets)]
        names = sheet_names([d.size for d in ordered])
        summary = self.wb.add_worksheet(SUMMARY_SHEET)  # created first so it is the first tab
        all_stats: dict[int, list[AlgStats]] = {}
        mean_pos: dict[int, dict[str, tuple[int, int]]] = {}
        for d in ordered:
            all_stats[d.size], mean_pos[d.size] = write_size_sheet(self, names[d.size], d)
        write_summary_sheet(self, summary, ordered, names, all_stats, mean_pos, sources)
        self.wb.close()
