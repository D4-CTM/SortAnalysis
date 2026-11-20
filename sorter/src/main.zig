const std = @import("std");
const Io = std.Io;

const sorter = @import("sorter");
const allocator = std.heap.page_allocator;

const Args = std.process.Args.Iterator;
const eql = std.mem.eql;

fn createFile(io: Io, path: []const u8) !Io.File {
    return if (std.fs.path.isAbsolute(path))
        try Io.Dir.createFileAbsolute(io, path, .{})
    else
        try Io.Dir.cwd().createFile(io, path, .{});
}

fn outCsvHelp() void {
    std.log.info("[-o|--out-csv] <path to csv ouput>", .{});
}

fn minArraySizeHelp() void {
    std.log.info("[--min|--min-array-size] <positive integer>", .{});
}

fn midArraySizeHelp() void {
    std.log.info("[--mid|--mid-array-size] <positive integer>", .{});
}

fn maxArraySizeHelp() void {
    std.log.info("[--max|--max-array-size] <positive integer>", .{});
}

fn iterationsHelp() void {
    std.log.info("[-i|--iterations] <positive integer>", .{});
}

fn help() void {
    std.log.info("Usage: <path to analyzer> [flags]", .{});
    std.log.info("Flags usage:", .{});
    minArraySizeHelp();
    midArraySizeHelp();
    maxArraySizeHelp();
    iterationsHelp();
    outCsvHelp();
}

const CliArgs = struct {
    iterations: u8 = 3,
    minArraySize: ?u64,
    midArraySize: ?u64,
    maxArraySize: ?u64,
    outCsv: []const u8,

    pub fn parse(args: *Args) !CliArgs {
        var outCsv: []const u8 = "out.csv";
        var iterations: u8 = 3;
        var minArraySize: ?u64 = null;
        var midArraySize: ?u64 = null;
        var maxArraySize: ?u64 = null;

        while (args.next()) |next| {
            const arg: []const u8 = next;
            if (eql(u8, arg, "-o") or eql(u8, arg, "--out-csv")) {
                if (args.next()) |csvPath| {
                    outCsv = csvPath;
                    continue;
                }

                outCsvHelp();
                return error.MissingOutCsvPath;
            } else if (eql(u8, arg, "--min") or eql(u8, arg, "--min-array-size")) {
                if (args.next()) |min| {
                    minArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        std.log.err("Invalid min size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                minArraySizeHelp();
                return error.MissingMinArraySize;
            } else if (eql(u8, arg, "--mid") or eql(u8, arg, "--mid-array-size")) {
                if (args.next()) |min| {
                    midArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        std.log.err("Invalid mid size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                midArraySizeHelp();
                return error.MissingMidArraySize;
            } else if (eql(u8, arg, "--max") or eql(u8, arg, "--max-array-size")) {
                if (args.next()) |min| {
                    maxArraySize = std.fmt.parseInt(u64, min, 10) catch |err| {
                        std.log.err("Invalid max size: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                maxArraySizeHelp();
                return error.MissingMaxArraySize;
            } else if (eql(u8, arg, "-i") or eql(u8, arg, "--iterations")) {
                if (args.next()) |min| {
                    iterations = std.fmt.parseInt(u8, min, 10) catch |err| {
                        std.log.err("Invalid iterations: {s}. Expected positive integer value", .{min});
                        return err;
                    };
                    continue;
                }

                iterationsHelp();
                return error.MissingIterations;
            }
        }

        if (minArraySize == null and midArraySize == null and maxArraySize == null) {
            std.log.err("Expected at least one array size defined: [--min|--mid|--max] <positive integer>", .{});
            return error.MissingArraySize;
        }

        if (iterations == 0) {
            std.log.err("Expected iterations to be greater than 0: [-i|--iterations] <positive integer greater than 0>", .{});
            return error.InvalidIteration;
        }

        return .{
            .minArraySize = minArraySize,
            .midArraySize = midArraySize,
            .maxArraySize = maxArraySize,
            .iterations = iterations,
            .outCsv = outCsv,
        };
    }
};

const Algorithms = struct { name: []const u8, alg: *const fn ([]usize) void };

const algs = [_]Algorithms{
    .{ .name = "Bubble Sort", .alg = &sorter.Algorithms.bubbleSort },
    .{ .name = "Insertion Sort", .alg = &sorter.Algorithms.insertionSort },
};

fn iterate(io: Io, w: *Io.Writer, iters: u16, allocSize: u64) !void {
    const data = try allocator.alloc(usize, allocSize);
    defer allocator.free(data);

    var prng = std.Random.DefaultPrng.init(val: {
        const now = Io.Clock.real.now(io);
        break :val @intCast(now.toMicroseconds());
    });
    const rng = prng.random();

    try w.print("data size,{d}\n", .{allocSize});
    try w.print("iteration,bubble sort\n", .{});
    for (0..iters) |it| {
        try w.print("{d},", .{it});
        for (algs) |alg| {
            rng.bytes(std.mem.sliceAsBytes(data));
            const duration = sorter.measure(io, alg.name, alg.alg, data);
            try duration.format(w);
            try w.writeByte(',');
        }
        try w.writeByte('\n');
        try w.flush();
    }
    try w.writeByte('\n');
    try w.flush();
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();

    const cli = try CliArgs.parse(&args);

    var file = try createFile(init.io, cli.outCsv);
    defer file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var writer = file.writerStreaming(init.io, &buffer);

    try writer.interface.print("Date,", .{});
    {
        const now = std.Io.Clock.real.now(init.io);
        const secs = now.toSeconds();

        const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(secs) };
        const yd = es.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        const ds = es.getDaySeconds();

        try writer.interface.print("{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}\n\n", .{
            yd.year,              md.month.numeric(),      md.day_index + 1,
            ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
        });
        try writer.interface.flush();
    }

    if (cli.minArraySize) |min| {
        try iterate(init.io, &writer.interface, cli.iterations, min);
    }

    if (cli.midArraySize) |mid| {
        try iterate(init.io, &writer.interface, cli.iterations, mid);
    }

    if (cli.maxArraySize) |max| {
        try iterate(init.io, &writer.interface, cli.iterations, max);
    }
}
