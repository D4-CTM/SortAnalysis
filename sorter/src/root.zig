const std = @import("std");
const Io = std.Io;

pub const Algorithms = @import("algorithms.zig");

const TimeStamp = std.Io.Clock.Timestamp;
const Duration = std.Io.Duration;

pub fn measure(io: Io, name: []const u8, alg: *const fn([]usize) void, arg: []usize) Duration {
    std.log.info("Measuring: {s}", .{name});
    const start = TimeStamp.now(io, .awake);
    alg(arg);
    const end = TimeStamp.now(io, .awake);

    return start.durationTo(end).raw;
}
