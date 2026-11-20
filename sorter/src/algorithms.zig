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

    for (0..(len-1)) |i| {
        for (0..(len-i-1)) |j| {
            if (data[j] > data[j+1]) {
                swap(&data[j], &data[j+1]);
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

fn testRunner(sortFn: *const fn(d: []usize) void) !void {
    const t = std.testing;

    const sortedData = [_]usize{ 1, 12, 15, 42, 50, 89 };

    var hardData = [_]usize{ 1, 15, 42, 12, 89, 50 };
    const softData = &hardData;

    sortFn(softData);

    for (sortedData, softData) |e, a| {
        try t.expectEqual(e, a);
    }
}

test "Test sorts" {
    try testRunner(&bubbleSort);
    try testRunner(&insertionSort);
}
