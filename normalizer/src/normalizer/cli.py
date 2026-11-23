"""Command-line entry point."""

import argparse
from pathlib import Path

from .notes import PreviousNotes, read_previous_notes
from .parsing import load_csvs
from .report import Report
from .xlutil import human_size


def main():
    parser = argparse.ArgumentParser(
        prog="normalizer",
        description="Normalize the sorter's CSV executions and export them to a single Excel report.",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-f", "--file", type=Path, action="append",
                       help="a CSV file (can be repeated)")
    group.add_argument("-d", "--dir", type=Path, help="a directory of CSV files")
    parser.add_argument("-o", "--output", type=Path, default=Path("report.xlsx"),
                        help="output .xlsx path (default: %(default)s)")
    parser.add_argument("--discard-notes", action="store_true",
                        help="don't carry over Reason/Notes text from an existing output file")
    args = parser.parse_args()

    if args.file:
        files = args.file
    else:
        if not args.dir.is_dir():
            parser.error(f"{args.dir} is not a directory")
        files = sorted(args.dir.glob("*.csv"))
    missing = [p for p in files if not p.is_file()]
    if missing:
        parser.error(f"not a file: {', '.join(map(str, missing))}")
    if not files:
        parser.error("no CSV files found")

    datasets, algorithms, sources = load_csvs(files)
    if not datasets:
        parser.error("the CSV files contain no data rows")

    prev = PreviousNotes() if args.discard_notes else read_previous_notes(args.output)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    Report(args.output, algorithms, prev).build(datasets, sources)

    kept = len(prev.reasons) + len(prev.notes)
    print(f"Read {sum(n for _, n in sources)} rows from {len(sources)} file(s)")
    for size in sorted(datasets):
        print(f"  {human_size(size):>6}: {len(datasets[size].runs)} run(s)")
    print(f"Wrote {args.output}" + (f" (kept {kept} hand-written note(s))" if kept else ""))
