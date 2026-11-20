//! Collection of in-place sort algorithms used during the program.
const std = @import("std");
const Io = std.Io;

fn swap(a: *usize, b: *usize) void {
    a.* = a.* ^ b.*;
    b.* = a.* ^ b.*;
    a.* = a.* ^ b.*;
}

/// O(n^2)
pub fn bubbleSort(data: []usize) void {
    const len = data.len;
    if (len <= 1)
        return;

    for (0..len) |i| {
        for (i..len) |j| {
            if (data[i] > data[j]) {
                swap(&data[i], &data[j]);
            }
        }
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

test "Test bubble sort" {
    const t = std.testing;

    const sortedData = [_]usize{ 1, 12, 15, 42, 50, 89 };

    var hardData = [_]usize{ 1, 15, 42, 12, 89, 50 };
    const softData = &hardData;

    bubbleSort(softData);

    for (sortedData, softData) |e, a| {
        try t.expectEqual(e, a);
    }
}

test "Test insertion sort" {
    const t = std.testing;

    const sortedData = [_]usize{ 1, 12, 15, 42, 50, 89 };

    var hardData = [_]usize{ 1, 15, 42, 12, 89, 50 };
    const softData = &hardData;

    insertionSort(softData);

    for (sortedData, softData) |e, a| {
        try t.expectEqual(e, a);
    }
}
