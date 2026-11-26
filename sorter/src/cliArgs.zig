const std = @import("std");
const builtin = @import("builtin");

const algorithms = @import("algorithms.zig");

const eql = std.mem.eql;
const Io = std.Io;

// Help texts are comptime strings: printing them costs a single write syscall,
// with no formatting at runtime.

const outCsvHelp =
    \\  -o, --out-csv <path>             CSV file where results are written.
    \\                                   Relative or absolute path. (default: out.csv)
    \\
;

const minArraySizeHelp =
    \\      --min, --min-array-size <n>  Number of elements of the "small" dataset.
    \\
;

const midArraySizeHelp =
    \\      --mid, --mid-array-size <n>  Number of elements of the "medium" dataset.
    \\
;

const maxArraySizeHelp =
    \\      --max, --max-array-size <n>  Number of elements of the "large" dataset.
    \\
;

const iterationsHelp =
    \\  -i, --iterations <n>             Times every algorithm runs per dataset size,
    \\                                   1-255. (default: 3)
    \\
;

const seedHelp =
    \\  -sd, --seed <n>                  Seed that will be used to fill the dataset,
    \\                                   Accepts: Binary (0b), Octal (0o), Hex (0x) and decimal formats. (default: 0x5eed)
    \\
;

const skipHelp = val: {
    var out: []const u8 =
        \\  -s, --skip <alg[,alg...]>        Algorithms to skip (written as "skipped" in the CSV),
        \\                                   comma separated, lowercase. Available:
        \\
    ;
    for (@typeInfo(algorithms).@"struct".decl_names) |decl| {
        out = out ++ "                                     - " ++ std.mem.trimEnd(u8, decl, "Sort") ++ "\n";
    }
    break :val out;
};

const help =
    \\sorter - benchmarks sorting algorithms over arrays of random integers
    \\
    \\Usage:
    \\  sorter [--min <n>] [--mid <n>] [--max <n>] [options]
    \\  zig build run -Doptimize=ReleaseFast -- [--min <n>] [--mid <n>] [--max <n>] [options]
    \\
    \\Dataset sizes (at least one is required; each is a positive integer):
    \\
++ minArraySizeHelp ++ midArraySizeHelp ++ maxArraySizeHelp ++
    \\
    \\  Each element is an i32 (4 bytes), so 1,000,000,000 elements need ~3.73 GiB of RAM.
    \\
    \\Options:
    \\
++ iterationsHelp ++ outCsvHelp ++ seedHelp ++ skipHelp ++
    \\  -h, --help                       Show this help and exit.
    \\
    \\Output:
    \\  One CSV row per (size, iteration): DataSize,Iteration,<Algorithm> Ms,...
    \\  Cells are "<n> ms", "skipped", or "N/A" if the algorithm failed.
    \\
    \\Examples:
    \\  sorter --min 10000 --mid 100000 --max 1000000
    \\  sorter --max 100000000 -i 5 -s bubble,selection,insertion -o executions/100M.csv
    \\
;

/// Writes a comptime-known text to `file` with one unbuffered write.
fn writeText(io: Io, file: Io.File, comptime text: []const u8) void {
    var w = file.writerStreaming(io, &.{});
    w.interface.writeAll(text) catch {};
}

fn usage(io: Io, comptime text: []const u8) void {
    // Tests exercise the error paths on purpose; keep their output clean.
    if (builtin.is_test) return;
    writeText(io, Io.File.stderr(), "Usage:\n" ++ text);
}

/// `std.log.err` that stays quiet in test builds: the 0.17 test runner marks
/// any test that logs an error as failed, even when the error is expected.
fn logErr(comptime fmt: []const u8, args: anytype) void {
    if (builtin.is_test) return;
    std.log.err(fmt, args);
}

pub const CliArgs = struct {
    iterations: u8 = 3,
    minArraySize: ?u64,
    midArraySize: ?u64,
    maxArraySize: ?u64,
    seed: u64,
    skip: []const u8 = "",
    outCsv: []const u8,

    /// `args` is any iterator with `next() ?[]const u8` and `skip() bool`
    /// (e.g. `*std.process.Args.Iterator`). The first item is the program name.
    pub fn parse(io: Io, args: anytype) !CliArgs {
        var outCsv: []const u8 = "out.csv";
        var skip: []const u8 = "";
        var iterations: u8 = 3;
        var seed: u64 = 0x5eed;
        var minArraySize: ?u64 = null;
        var midArraySize: ?u64 = null;
        var maxArraySize: ?u64 = null;

        _ = args.skip(); // program name

        while (args.next()) |next| {
            const arg: []const u8 = next;
            if (eql(u8, arg, "-o") or eql(u8, arg, "--out-csv")) {
                if (args.next()) |csvPath| {
                    outCsv = csvPath;
                    continue;
                }

                usage(io, outCsvHelp);
                return error.MissingOutCsvPathArg;
            } else if (eql(u8, arg, "--min") or eql(u8, arg, "--min-array-size")) {
                if (args.next()) |min| {
                    minArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        logErr("Invalid min size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                usage(io, minArraySizeHelp);
                return error.MissingMinArraySizeArg;
            } else if (eql(u8, arg, "--mid") or eql(u8, arg, "--mid-array-size")) {
                if (args.next()) |min| {
                    midArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        logErr("Invalid mid size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                usage(io, midArraySizeHelp);
                return error.MissingMidArraySize;
            } else if (eql(u8, arg, "--max") or eql(u8, arg, "--max-array-size")) {
                if (args.next()) |min| {
                    maxArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        logErr("Invalid max size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                usage(io, maxArraySizeHelp);
                return error.MissingMaxArraySizeArg;
            } else if (eql(u8, arg, "-i") or eql(u8, arg, "--iterations")) {
                if (args.next()) |min| {
                    iterations = std.fmt.parseInt(u8, min, 10) catch |err| {
                        logErr("Invalid iterations: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                usage(io, iterationsHelp);
                return error.MissingIterationsArg;
            } else if (eql(u8, arg, "-s") or eql(u8, arg, "--skip")) {
                if (args.next()) |skipArg| {
                    skip = skipArg;
                    continue;
                }
                
                usage(io, skipHelp);
                return error.MissingSkipArg;
            } else if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
                writeText(io, Io.File.stdout(), help);
                std.process.exit(0);
            } else if (eql(u8, arg, "-sd") or eql(u8, arg, "--seed")) {
                if (args.next()) |sd| {
                    seed = std.fmt.parseInt(u64, sd, 0) catch |err| {
                        logErr("Invalid seed: {s}. Expected positive integer value", .{sd});
                        return err;
                    };
                    continue;
                }
                
                usage(io, seedHelp);
                return error.MissingSeedArg;
            } else {
                logErr("Unknown argument: {s}. Use --help to see the available flags", .{arg});
                return error.UnknownArgument;
            }
        }

        if (minArraySize == null and midArraySize == null and maxArraySize == null) {
            logErr("Expected at least one array size defined: [--min|--mid|--max] <positive integer>. Use --help for more info", .{});
            return error.MissingArraySize;
        }

        if (iterations == 0) {
            logErr("Expected iterations to be greater than 0: [-i|--iterations] <positive integer greater than 0>", .{});
            return error.InvalidIteration;
        }

        return .{
            .minArraySize = minArraySize,
            .midArraySize = midArraySize,
            .maxArraySize = maxArraySize,
            .iterations = iterations,
            .seed = seed,
            .skip = skip,
            .outCsv = outCsv,
        };
    }
};


// ---------------------------------------------------------------------------
// Tests
//
// `--help` is not tested here because it calls `std.process.exit(0)`.
// ---------------------------------------------------------------------------

const testing = std.testing;
const TestArgs = std.process.Args.IteratorGeneral(.{});

/// Parses `cmd_line` as if it were typed after the program name.
/// Returned slices point into `it`, so keep it alive while checking them.
fn parseLine(it: *TestArgs, cmd_line: []const u8) !CliArgs {
    it.* = try TestArgs.init(testing.allocator, cmd_line);
    return CliArgs.parse(testing.io, it);
}

fn expectParseError(expected: anyerror, cmd_line: []const u8) !void {
    var it: TestArgs = undefined;
    defer it.deinit();
    try testing.expectError(expected, parseLine(&it, cmd_line));
}

test "defaults when only one size is given" {
    var it: TestArgs = undefined;
    defer it.deinit();
    const cli = try parseLine(&it, "sorter --min 10");

    try testing.expectEqual(@as(?u64, 10), cli.minArraySize);
    try testing.expectEqual(@as(?u64, null), cli.midArraySize);
    try testing.expectEqual(@as(?u64, null), cli.maxArraySize);
    try testing.expectEqual(3, cli.iterations);
    try testing.expectEqual(@as(u64, 0x5eed), cli.seed);
    try testing.expectEqualStrings("out.csv", cli.outCsv);
    try testing.expectEqualStrings("", cli.skip);
}

test "seed accepts decimal and prefixed bases" {
    const cases = [_]struct { cmd: []const u8, value: u64 }{
        .{ .cmd = "sorter --min 10 -sd 42", .value = 42 },
        .{ .cmd = "sorter --min 10 --seed 42", .value = 42 },
        .{ .cmd = "sorter --min 10 --seed 0x2a", .value = 42 },
        .{ .cmd = "sorter --min 10 --seed 0b101010", .value = 42 },
        .{ .cmd = "sorter --min 10 --seed 0o52", .value = 42 },
    };
    inline for (cases) |case| {
        var it: TestArgs = undefined;
        defer it.deinit();
        const cli = try parseLine(&it, case.cmd);
        try testing.expectEqual(case.value, cli.seed);
    }
}

test "long flags" {
    var it: TestArgs = undefined;
    defer it.deinit();
    const cli = try parseLine(&it,
        "sorter --min-array-size 1 --mid-array-size 2 --max-array-size 3 " ++
        "--iterations 7 --out-csv results/a.csv --skip bubble,heap");

    try testing.expectEqual(@as(?u64, 1), cli.minArraySize);
    try testing.expectEqual(@as(?u64, 2), cli.midArraySize);
    try testing.expectEqual(@as(?u64, 3), cli.maxArraySize);
    try testing.expectEqual(7, cli.iterations);
    try testing.expectEqualStrings("results/a.csv", cli.outCsv);
    try testing.expectEqualStrings("bubble,heap", cli.skip);
}

test "short flags, any order" {
    var it: TestArgs = undefined;
    defer it.deinit();
    const cli = try parseLine(&it, "sorter -s quick -o /tmp/x.csv --max 1000000000 -i 255 --mid 5");

    try testing.expectEqual(@as(?u64, null), cli.minArraySize);
    try testing.expectEqual(@as(?u64, 5), cli.midArraySize);
    try testing.expectEqual(@as(?u64, 1_000_000_000), cli.maxArraySize);
    try testing.expectEqual(255, cli.iterations);
    try testing.expectEqualStrings("/tmp/x.csv", cli.outCsv);
    try testing.expectEqualStrings("quick", cli.skip);
}

test "last occurrence of a flag wins" {
    var it: TestArgs = undefined;
    defer it.deinit();
    const cli = try parseLine(&it, "sorter --min 1 --min 2 -o a.csv -o b.csv");

    try testing.expectEqual(@as(?u64, 2), cli.minArraySize);
    try testing.expectEqualStrings("b.csv", cli.outCsv);
}

test "program name is not treated as an argument" {
    // A program name that looks like a flag must still be skipped.
    var it: TestArgs = undefined;
    defer it.deinit();
    const cli = try parseLine(&it, "--min --max 4");
    try testing.expectEqual(@as(?u64, null), cli.minArraySize);
    try testing.expectEqual(@as(?u64, 4), cli.maxArraySize);
}

test "missing array size" {
    try expectParseError(error.MissingArraySize, "sorter");
    try expectParseError(error.MissingArraySize, "sorter -i 3 -o a.csv -s bubble");
}

test "flag without its value" {
    try expectParseError(error.MissingMinArraySizeArg, "sorter --min");
    try expectParseError(error.MissingMidArraySize, "sorter --mid");
    try expectParseError(error.MissingMaxArraySizeArg, "sorter --max");
    try expectParseError(error.MissingIterationsArg, "sorter --min 1 -i");
    try expectParseError(error.MissingOutCsvPathArg, "sorter --min 1 -o");
    try expectParseError(error.MissingSkipArg, "sorter --min 1 -s");
    try expectParseError(error.MissingSeedArg, "sorter --min 1 -sd");
    try expectParseError(error.MissingSeedArg, "sorter --min 1 --seed");
}

test "invalid numbers" {
    try expectParseError(error.InvalidCharacter, "sorter --min abc");
    try expectParseError(error.Overflow, "sorter --min -5"); // negative into u64
    try expectParseError(error.InvalidCharacter, "sorter --max 1.5");
    try expectParseError(error.InvalidCharacter, "sorter --min 10 -i three");
    try expectParseError(error.Overflow, "sorter --min 18446744073709551616"); // u64 max + 1
    try expectParseError(error.Overflow, "sorter --min 10 -i 256"); // u8 max + 1
    try expectParseError(error.InvalidCharacter, "sorter --min 10 --seed xyz");
    try expectParseError(error.Overflow, "sorter --min 10 --seed 18446744073709551616"); // u64 max + 1
}

test "zero iterations" {
    try expectParseError(error.InvalidIteration, "sorter --min 10 -i 0");
}

test "unknown arguments" {
    try expectParseError(error.UnknownArgument, "sorter --min 10 --bogus");
    try expectParseError(error.UnknownArgument, "sorter --min 10 extra");
    try expectParseError(error.UnknownArgument, "sorter -m 10");
}

test "help text lists every algorithm" {
    inline for (@typeInfo(algorithms).@"struct".decl_names) |decl| {
        const name = comptime std.mem.trimEnd(u8, decl, "Sort");
        try testing.expect(std.mem.find(u8, help, "- " ++ name ++ "\n") != null);
    }
}
