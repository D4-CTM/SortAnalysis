# normalizer

> [!IMPORTANT]
Normalizer made and enhanced using AI.

Turns the sorter's CSV executions into a single Excel report.

```sh
# from the repo root: run the sorter, writing CSVs into executions/
# then, from normalizer/:
uv run normalizer -d ../executions -o ../report.xlsx
```

Options:

| Flag | Meaning |
| --- | --- |
| `-d, --dir DIR` | read every `*.csv` in `DIR` |
| `-f, --file FILE` | read a single CSV (repeatable) |
| `-o, --output PATH` | output `.xlsx` (default `report.xlsx`) |
| `--discard-notes` | don't carry over hand-written text from an existing report |

## What's in the report

- **Summary**: mean time per algorithm × dataset size, slowdown relative to the
  fastest algorithm at each size, the fastest algorithm per size (with links to
  each sheet), the source files read, a log-log scaling chart, and a grouped
  "x slower than fastest" chart.
- **One sheet per dataset size** (`1M`, `10M`, `1B`, …), merging every run of
  that size from all CSVs:
  - a performance table sorted fastest → slowest: min / max / mean / median /
    std dev, throughput (million elements/s), slowdown vs fastest, and rank.
    These are live formulas over the raw runs.
  - **Skipped executions**: every algorithm with skipped runs, with a yellow
    *Reason (fill in)* cell for you to explain why.
  - a yellow **Notes** box.
  - the raw runs (grey cells are skipped executions).
  - charts: mean time (with std-dev error bars), throughput, and time per run.
    Axes switch to a log scale when algorithms differ by 100x or more.

## Your notes are kept

When the output file already exists, the text you typed into the *Reason* and
*Notes* cells is read back and written into the new report. That way you can
add new CSVs to `executions/` and regenerate without losing your explanations.
Reasons are matched by sheet name and algorithm. Close the file in Excel before
regenerating.

## Input format

The CSVs are the sorter's output: `DataSize,Iteration,<Algorithm> Ms,...`, with
cells such as `91951 ms` or `skipped`. Trailing commas, empty cells, and
algorithm columns that differ between files are all handled.

`0 ms` means the sort finished faster than the sorter's 1 ms timer resolution.
It counts as a measurement in min / max / mean, but throughput and "x slower"
ratios that would divide by it show `< 1 ms` or `n/a` instead. Charts leave
those points out, because a log axis can't plot 0.
