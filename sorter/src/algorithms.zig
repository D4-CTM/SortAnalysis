//! Collection of in-place sort algorithms used during the program.
const std = @import("std");
const Io = std.Io;

const allocator = std.heap.page_allocator;

// Using both xor and normal swap prove to be meaningless, almost no visible
// change was visible in the output .csv so it was decided to use the regular swap.
inline fn xorSwap(noalias a: *i32, noalias b: *i32) void {
    a.* = a.* ^ b.*;
    b.* = a.* ^ b.*;
    a.* = a.* ^ b.*;
}

inline fn swap(noalias a: *i32, noalias b: *i32) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

/// O(n^2)
pub fn bubbleSort(data: []i32) !void {
    const len = data.len;
    if (len <= 1)
        return;

    var swapped = false;
    for (0..(len - 1)) |i| {
        swapped = false;
        for (0..(len - i - 1)) |j| {
            if (data[j] > data[j + 1]) {
                swap(&data[j], &data[j + 1]);
                swapped = true;
            }
        }

        if (!swapped)
            return;
    }
}

/// O(n^2)
pub fn selectionSort(data: []i32) !void {
    const len = data.len;
    if (len <= 1)
        return;

    var minIdx: usize = 0;
    for (0..len - 1) |i| {
        minIdx = i;

        for ((i + 1)..len) |j| {
            if (data[j] < data[minIdx]) {
                minIdx = j;
            }
        }

        if (minIdx != i)
            swap(&data[i], &data[minIdx]);
    }
}

/// O(n^2)
pub fn insertionSort(data: []i32) !void {
    const len = data.len;
    if (len <= 1)
        return;

    for (1..len) |i| {
        const key = data[i];

        var j = i;
        while (j > 0 and data[j - 1] > key) : (j -= 1) {
            data[j] = data[j - 1];
        }

        data[j] = key;
    }
}

/// O(n log n)
/// Algorithm based in the `geekforgeek` implementation.
pub fn quickSort(data: []i32) !void {
    qSort(data, 0, data.len);
}

fn partition(data: []i32, low: usize, high: usize) usize {
    const pi = data[high - 1];
    var i: usize = low;

    for (low..high) |j| {
        if (data[j] < pi) {
            swap(&data[i], &data[j]);
            i += 1;
        }
    }

    swap(&data[i], &data[high - 1]);
    return i;
}

fn qSort(data: []i32, low: usize, high: usize) void {
    if (low >= high)
        return;

    const mid = partition(data, low, high);

    qSort(data, low, mid);
    qSort(data, mid + 1, high);
}

/// O(n log n)
pub fn heapSort(data: []i32) !void {
    const len = data.len;
    if (len <= 1)
        return;

    var max: usize = (len / 2);
    while (max > 0) {
        max -= 1;
        heapify(data, len, max);
    }

    var end = len - 1;
    while (end > 0) : (end -= 1) {
        swap(&data[0], &data[end]);

        heapify(data, end, 0);
    }
}

fn heapify(data: []i32, n: usize, i: usize) void {
    var largest = i;

    const l = 2 * i + 1;
    const r = 2 * i + 2;

    if (l < n and data[l] > data[largest])
        largest = l;

    if (r < n and data[r] > data[largest])
        largest = r;

    if (largest != i) {
        swap(&data[i], &data[largest]);

        heapify(data, n, largest);
    }
}

pub fn mergeSort(data: []i32) !void {
    const scratch = try allocator.alloc(i32, data.len);
    defer allocator.free(scratch);
    @memcpy(scratch, data);

    sortInto(data, scratch);
}

fn sortInto(dst: []i32, src: []i32) void {
    std.debug.assert(dst.len == src.len);
    if (dst.len <= 1) return;

    const mid = dst.len / 2;

    sortInto(src[0..mid], dst[0..mid]);
    sortInto(src[mid..], dst[mid..]);

    var l: usize = 0;
    var r: usize = mid;
    for (dst) |*slot| {
        // optimization proposed by **claude**
        if (r >= src.len or (l < mid and src[l] <= src[r])) {
            slot.* = src[l];
            l += 1;
        } else {
            slot.* = src[r];
            r += 1;
        }
    }
}
// ---------------------------------------------------------------------------
// Tests
//
// Every `pub` sort in this file is picked up automatically (same reflection
// `main.zig` uses), so a newly added algorithm is tested without touching
// anything here. The expected output always comes from `std.mem.sort`, which
// checks both that the result is ordered and that it is a permutation of the
// input (nothing lost, duplicated or invented).
// ---------------------------------------------------------------------------

const testing = std.testing;

const SortFn = *const fn ([]i32) anyerror!void;

const TestAlg = struct { name: []const u8, sort: SortFn };

const test_algs: []const TestAlg = val: {
    const decls = @typeInfo(@This()).@"struct".decl_names;
    var out: [decls.len]TestAlg = undefined;
    for (decls, 0..) |decl, i| {
        out[i] = .{ .name = decl, .sort = &@field(@This(), decl) };
    }
    const final = out;
    break :val &final;
};

/// Sorts a copy of `input` with every algorithm and compares it with
/// `std.mem.sort`. On failure, prints which algorithm and case broke.
fn expectSortsLikeStd(case: []const u8, input: []const i32) !void {
    const expected = try testing.allocator.dupe(i32, input);
    defer testing.allocator.free(expected);
    std.mem.sort(i32, expected, {}, std.sort.asc(i32));

    const actual = try testing.allocator.alloc(i32, input.len);
    defer testing.allocator.free(actual);

    for (test_algs) |alg| {
        @memcpy(actual, input);
        errdefer std.debug.print("\n{s} failed on case \"{s}\" (len {d})\n", .{ alg.name, case, input.len });
        try alg.sort(actual);
        try testing.expectEqualSlices(i32, expected, actual);
    }
}

test "all algorithms are discovered" {
    try testing.expectEqual(6, test_algs.len);
}

test "original sample" {
    try expectSortsLikeStd("sample", &.{ 1, 15, 42, 12, 89, 50 });
}

test "trivial inputs: empty, one and two elements" {
    try expectSortsLikeStd("empty", &.{});
    try expectSortsLikeStd("single", &.{42});
    try expectSortsLikeStd("pair sorted", &.{ 1, 2 });
    try expectSortsLikeStd("pair reversed", &.{ 2, 1 });
    try expectSortsLikeStd("pair equal", &.{ 7, 7 });
    try expectSortsLikeStd("three reversed", &.{ 3, 2, 1 });
}

test "already sorted and reversed" {
    var sorted: [1000]i32 = undefined;
    for (&sorted, 0..) |*v, i| v.* = @intCast(i);
    try expectSortsLikeStd("sorted", &sorted);

    var reversed: [1000]i32 = undefined;
    for (&reversed, 0..) |*v, i| v.* = @intCast(reversed.len - i);
    try expectSortsLikeStd("reversed", &reversed);
}

test "duplicates" {
    const all_equal: [500]i32 = @splat(9);
    try expectSortsLikeStd("all equal", &all_equal);

    var few_values: [1000]i32 = undefined;
    for (&few_values, 0..) |*v, i| v.* = @intCast((i * 7) % 3);
    try expectSortsLikeStd("only 0, 1 and 2", &few_values);

    try expectSortsLikeStd("duplicated pairs", &.{ 5, 1, 5, 1, 3, 3, 0, 0 });
}

test "extreme values" {
    const max = std.math.maxInt(i32);
    try expectSortsLikeStd("min and max", &.{ max, 0, max - 1, 1, max, 0 });
    try expectSortsLikeStd("only max", &.{ max, max, max });
}

test "organ pipe and sawtooth patterns" {
    var organ: [999]i32 = undefined;
    for (&organ, 0..) |*v, i| v.* = @intCast(@min(i, organ.len - i));
    try expectSortsLikeStd("organ pipe", &organ);

    var saw: [1000]i32 = undefined;
    for (&saw, 0..) |*v, i| v.* = @intCast(i % 37);
    try expectSortsLikeStd("sawtooth", &saw);
}

test "random data, many sizes and seeds" {
    // Fixed seed so a failure can be reproduced.
    var prng = std.Random.DefaultPrng.init(0x5eed_5eed);
    const rng = prng.random();

    const sizes = [_]usize{ 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 100, 127, 128, 129, 1000, 1023, 1024, 1025, 4096 };
    for (sizes) |size| {
        const data = try testing.allocator.alloc(i32, size);
        defer testing.allocator.free(data);

        for (0..5) |_| {
            // Full range: same kind of data the benchmark uses.
            rng.bytes(std.mem.sliceAsBytes(data));
            try expectSortsLikeStd("random full range", data);

            // Small range: forces lots of duplicates.
            for (data) |*v| v.* = @intCast(rng.uintLessThan(u32, 10));
            try expectSortsLikeStd("random small range", data);
        }
    }
}
