const std = @import("std");
const Io = std.Io;

const allocator = std.heap.page_allocator;

const sorter = @import("sorter");

fn createFile(io: Io, path: []const u8) !Io.File {
    return if (std.fs.path.isAbsolute(path))
        try Io.Dir.createFileAbsolute(io, path, .{})
    else
        try Io.Dir.cwd().createFile(io, path, .{});
}

const Algorithms = struct {
    prettyName: []const u8,
    rawName: []const u8,
    alg: *const fn ([]usize) anyerror!void,
};

fn prettifyName(comptime name: []const u8) []const u8 {
    comptime var out: []const u8 = "";
    out = out ++ [1]u8{std.ascii.toUpper(name[0])};

    inline for (name[1..name.len]) |ch| {
        if (std.ascii.isUpper(ch)) {
            out = out ++ " " ++ [1]u8{std.ascii.toUpper(ch)};
            continue;
        }

        out = out ++ [1]u8{ch};
    }

    return out;
}

const algs: []const Algorithms = val: {
    const t = @typeInfo(sorter.Algorithms).@"struct";
    var algsR: [t.decl_names.len]Algorithms = undefined;

    for (t.decl_names, 0..) |decl, idx| {
        algsR[idx] = .{
            .prettyName = prettifyName(decl),
            .rawName = std.mem.trimEnd(u8, decl, "Sort"),
            .alg = &@field(sorter.Algorithms, decl),
        };
    }

    const final = algsR;
    break :val &final;
};

fn printHeader(w: *Io.Writer) !void {
    comptime var names: []const u8 = "";
    inline for (algs) |alg| {
        names = names ++ "," ++ alg.prettyName ++ " Ms";
    }

    try w.writeAll("DataSize,Iteration" ++ names ++ "\n");
}

fn iterate(io: Io, w: *Io.Writer, skip: []const u8, iters: u16, allocSize: u64) !void {
    const data = try allocator.alloc(usize, allocSize);
    defer allocator.free(data);

    var prng = std.Random.DefaultPrng.init(val: {
        const now = Io.Clock.real.now(io);
        break :val @intCast(now.toMicroseconds());
    });
    const rng = prng.random();

    for (0..iters) |it| {
        try w.print("{d},{d}", .{ allocSize, it + 1 });
        for (algs) |alg| {
            if (std.mem.find(u8, skip, alg.rawName)) |_| {
                try w.writeAll(",skipped");
                continue;
            }
            rng.bytes(std.mem.sliceAsBytes(data));

            const duration = sorter.measure(io, alg.prettyName, alg.alg, data) catch |err| {
                std.log.err(",{s} threw: {any}", .{ alg.prettyName, err });
                try w.writeAll(",N/A");
                continue;
            };

            try w.print(",{d} ms", .{duration.toMilliseconds()});
        }
        try w.writeByte('\n');
        try w.flush();
    }
}

const gib: comptime_float = 1024 * 1024 * 1024;

fn gibConsumption(size: usize) void {
    const byteConsumed: f32 = @floatFromInt(@sizeOf(usize) * size);
    std.log.info("Gibs required: {d:.2}", .{byteConsumed/(gib)});
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();

    const cli = try sorter.CliArgs.parse(&args);

    var file = try createFile(init.io, cli.outCsv);
    defer file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var writer = file.writerStreaming(init.io, &buffer);

    try printHeader(&writer.interface);

    if (cli.minArraySize) |min| {
        gibConsumption(min);
        try iterate(init.io, &writer.interface, cli.skip, cli.iterations, min);
    }

    if (cli.midArraySize) |mid| {
        gibConsumption(mid);
        try iterate(init.io, &writer.interface, cli.skip, cli.iterations, mid);
    }

    if (cli.maxArraySize) |max| {
        gibConsumption(max);
        try iterate(init.io, &writer.interface, cli.skip, cli.iterations, max);
    }

    try writer.interface.flush();
}
