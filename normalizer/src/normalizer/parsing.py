"""Reading the sorter's CSV output into datasets grouped by size."""

import csv
import sys
from dataclasses import dataclass, field
from pathlib import Path

SKIPPED = "skipped"


@dataclass
class Run:
    source: str
    iteration: int
    times: dict[str, int | None]  # algorithm -> ms, None when skipped


@dataclass
class Dataset:
    size: int
    runs: list[Run] = field(default_factory=list)


def algorithm_name(column: str) -> str:
    column = column.strip()
    return column[:-3].strip() if column.lower().endswith(" ms") else column


def parse_ms(cell: str) -> int | None:
    cell = cell.strip().lower()
    if not cell or cell == SKIPPED:
        return None
    if cell.endswith("ms"):
        cell = cell[:-2].strip()
    return int(float(cell))


def load_csvs(files: list[Path]) -> tuple[dict[int, Dataset], list[str], list[tuple[str, int]]]:
    """Returns datasets keyed by size, algorithms in header order, and (file, rows) read."""
    datasets: dict[int, Dataset] = {}
    algorithms: list[str] = []
    sources: list[tuple[str, int]] = []

    for path in files:
        with path.open(newline="") as fh:
            reader = csv.reader(fh)
            header = next(reader, None)
            if not header:
                print(f"warning: {path} is empty, ignoring", file=sys.stderr)
                continue
            # The sorter may leave a trailing comma, producing empty columns.
            columns = [(i, algorithm_name(h)) for i, h in enumerate(header[2:], start=2) if h.strip()]
            for _, alg in columns:
                if alg not in algorithms:
                    algorithms.append(alg)

            count = 0
            for line_no, row in enumerate(reader, start=2):
                if not row or not any(c.strip() for c in row):
                    continue
                try:
                    size = int(row[0])
                    iteration = int(row[1])
                    times = {alg: parse_ms(row[i]) if i < len(row) else None for i, alg in columns}
                except (ValueError, IndexError) as e:
                    print(f"warning: {path}:{line_no} malformed row ({e}), ignoring", file=sys.stderr)
                    continue
                datasets.setdefault(size, Dataset(size)).runs.append(Run(path.name, iteration, times))
                count += 1
            sources.append((path.name, count))

    return datasets, algorithms, sources
