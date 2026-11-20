//! Collection of in-place sort algorithms used during the program.
const std = @import("std");
const Io = std.Io;

// Using both xor and normal swap prove to be meaningless, almost no visible
// change was visible in the output .csv so it was decided to use the regular swap.
inline fn xorSwap(noalias a: *usize, noalias b: *usize) void {
    a.* = a.* ^ b.*;
    b.* = a.* ^ b.*;
    a.* = a.* ^ b.*;
}

inline fn swap(noalias a: *usize, noalias b: *usize) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

/// O(n^2)
pub fn bubbleSort(data: []usize) void {
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
/// As found in geeksforgeeks. It knows if the elements in the array where
/// swapped and can exit early. For all intends and porpuses this is just
/// to see if it really makes any difference. Remove the `pub` modifier and recompile
/// to hide it in the results.
fn bubbleSortSwapMemory(data: []usize) void {
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
pub fn selectionSort(data: []usize) void {
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

        swap(&data[i], &data[minIdx]);
    }
}

/// O(n^2)
pub fn insertionSort(data: []usize) void {
    const len = data.len;
    if (len <= 1)
        return;

    var j: usize = 0;
    for (1..len) |i| {
        const key = data[i];
        j = i - 1;

        while (j >= 0 and data[j] > key) {
            data[j + 1] = data[j];

            if (j == 0)
                break;

            j -= 1;
        }

        data[j + 1] = key;
    }
}

/// O(n log n)
pub fn quickSort(data: []usize) void {
    qSort(data, 0, data.len);
}

fn partition(data: []usize, low: usize, high: usize) usize {
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

fn qSort(data: []usize, low: usize, high: usize) void {
    if (low >= high)
        return;

    const mid = partition(data, low, high);

    qSort(data, low, mid);
    qSort(data, mid + 1, high);
}

pub fn heapSort(data: []usize) void {
    const len = data.len;
    if (len <= 1)
        return;

    var max = (len / 2);
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

fn heapify(data: []usize, n: usize, i: usize) void {
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

fn testRunner(sortFn: *const fn (d: []usize) void) !void {
    const t = std.testing;

    const sortedData = [_]usize{ 1, 12, 15, 42, 50, 89 };

    var hardData = [_]usize{ 1, 15, 42, 12, 89, 50 };
    const softData = &hardData;

    sortFn(softData);

    try t.expectEqualSlices(usize, &sortedData, softData);
}

test "Test sort functionallity" {
    testRunner(&bubbleSort) catch return error.BubbleSort;
    testRunner(&insertionSort) catch return error.InsertionSort;
    testRunner(&selectionSort) catch return error.SelectionSort;
    testRunner(&quickSort) catch return error.QuickSort;
    testRunner(&heapSort) catch return error.HeapSort;
}
