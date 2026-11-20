//! Collection of in-place sort algorithms used during the program.
const std = @import("std");
const Io = std.Io;

fn swap(a: *usize, b: *usize) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

/// O(n^2)
pub fn bubbleSort(data: []usize) void {
    const len = data.len;
    if (len <= 1)
        return;

    // defined outside as a small optimization
    for (0..len) |i| {
        for (i..len) |j| {
            if (data[i] > data[j]) {
                swap(&data[i], &data[j]);
            }
        }
    }
}

test "Test bubble sort" {
    const t = std.testing;

    const sortedData = [_]usize{1, 12, 15, 42, 50, 89};

    var hardData = [_]usize{1, 15, 42, 12, 89, 50};
    const softData = &hardData;

    bubbleSort(softData);

    for (sortedData, softData) |e, a| {
        try t.expectEqual(e, a);
    }
}
