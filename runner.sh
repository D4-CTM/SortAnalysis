#!/bin/bash
# Grounded benchmark sequence.
#
# 1. Small sizes: all six algorithms, enough repetitions to see the O(n^2)
#    blow-up. Past ~100k elements bubble/selection/insertion stop being useful
#    to measure (minutes per single run at 1M).
# 2. From 500k on: only merge, heap and quick sort.
# 3. Grow toward the RAM limit in bigger jumps. 13.9 GiB usable at 4
#    bytes/element is 3,731,252,838 elements; merge sort needs an equally
#    sized scratch buffer, so with merge included the ceiling is half that.
#    The final run uses the literal whole budget with merge skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/sorter/zig-out/bin/sorter"
RUN_ID="$(date +%F_%H%M%S)"
OUT_DIR="$ROOT/executions/"

SLOW="bubble,selection,insertion"
SEED="0x5eed"

if [[ ! -x "$BIN" ]]; then
    echo "Missing $BIN" >&2
    echo "Build first: cd '$ROOT/sorter' && zig build -Doptimize=ReleaseFast" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
echo "Results: $OUT_DIR"

# All algorithms. O(n^2) is still cheap here.
"$BIN" --min 10_000 --mid 100_000 --max 500_000 -i 10 --seed "$SEED" \
    -o "$OUT_DIR/01-$RUN_ID-all-small.csv"

# First sizes where only the O(n log n) algorithms are timed.
"$BIN" --min 1_000_000 --mid 10_000_000 --max 50_000_000 -i 5 --seed "$SEED" \
    -s "$SLOW" -o "$OUT_DIR/02-$RUN_ID-fast-medium.csv"

# Larger jumps; merge sort's scratch buffer is still within the 13.9 GiB budget.
"$BIN" --min 100_000_000 --mid 500_000_000 --max 1_000_000_000 -i 3 --seed "$SEED" \
    -s "$SLOW" -o "$OUT_DIR/03-$RUN_ID-fast-large.csv"

"$BIN" --max 1_500_000_000 -i 3 --seed "$SEED" \
    -s "$SLOW" -o "$OUT_DIR/04-$RUN_ID-fast-max-with-merge.csv"

"$BIN" --max 1_865_626_419 -i 3 --seed "$SEED" -s "$SLOW" \
    -o "$OUT_DIR/05-$RUN_ID-fast-max-with-merge.csv"

# Literal whole budget: 13.9 GiB / 4 bytes = 3,731,252,838 i32 elements.
# This leaves zero headroom, so anything else that allocates may OOM.
"$BIN" --max 3_731_252_838 -i 3 --seed "$SEED" -s "$SLOW,merge" \
    -o "$OUT_DIR/05-$RUN_ID-fast-max-no-merge.csv"

echo "Done. CSVs in $OUT_DIR"
