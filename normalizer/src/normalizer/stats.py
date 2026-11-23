"""Per-algorithm statistics for one dataset."""

import statistics
from dataclasses import dataclass

from .parsing import Dataset


@dataclass
class AlgStats:
    name: str
    values: list[int]
    skipped: int

    @property
    def ok(self) -> bool:
        return bool(self.values)

    @property
    def mean(self) -> float | None:
        return statistics.fmean(self.values) if self.values else None

    @property
    def median(self) -> float | None:
        return statistics.median(self.values) if self.values else None

    @property
    def stdev(self) -> float | None:
        return statistics.stdev(self.values) if len(self.values) > 1 else None


def compute_stats(ds: Dataset, algorithms: list[str]) -> list[AlgStats]:
    out = []
    for alg in algorithms:
        values = [r.times[alg] for r in ds.runs if r.times.get(alg) is not None]
        out.append(AlgStats(alg, values, len(ds.runs) - len(values)))
    return out


def ranked(stats: list[AlgStats]) -> list[AlgStats]:
    """Fastest first, fully skipped algorithms last."""
    return sorted(stats, key=lambda s: (not s.ok, s.mean or 0))
