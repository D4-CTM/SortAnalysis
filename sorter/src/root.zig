const std = @import("std");
const Io = std.Io;

pub const Algorithms = @import("algorithms.zig");
pub const CliArgs = @import("cliArgs.zig").CliArgs;

const TimeStamp = std.Io.Clock.Timestamp;
const Duration = std.Io.Duration;

/// Output's duration will be affected by the fact it's a function pointer and not a direct function call,
/// however, it was tested the other way around and there was no visible difference so it was kept this way
/// as it was already made.
pub fn measure(io: Io, name: []const u8, alg: *const fn([]usize) anyerror!void, arg: []usize) !Duration {
    std.log.info("Measuring: {s} with {d} elements", .{name, arg.len});
    const start = TimeStamp.now(io, .awake);
    try alg(arg);
    const end = TimeStamp.now(io, .awake);

    return start.durationTo(end).raw;
}

// Zig only runs the tests of files referenced from a test block; without
// this, `zig build test` silently runs 0 tests.
test {
    _ = Algorithms;
    _ = @import("cliArgs.zig");
}
