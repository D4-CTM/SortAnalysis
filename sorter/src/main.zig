const std = @import("std");
const Io = std.Io;

const allocator = std.heap.page_allocator;

const sorter = @import("sorter");

const Algorithms = struct {
    name: []const u8,
    alg: *const fn ([]usize) void,
};

fn createFile(io: Io, path: []const u8) !Io.File {
    return if (std.fs.path.isAbsolute(path))
        try Io.Dir.createFileAbsolute(io, path, .{})
    else
        try Io.Dir.cwd().createFile(io, path, .{});
}

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

    for (t.decl_names, 0..) |declName, idx| {
        algsR[idx] = .{
            .name = prettifyName(declName),
            .alg = &@field(sorter.Algorithms, declName),
        };
    }

    const final = algsR;
    break :val &final;
};

fn printHeader(w: *Io.Writer) !void {
    comptime var names: []const u8 = "";
    inline for (algs) |alg| {
        names = names ++ alg.name ++ " Ms,";
    }

    try w.print("Iteration," ++ names ++ "\n", .{});
}

fn iterate(io: Io, w: *Io.Writer, iters: u16, allocSize: u64) !void {
    const data = try allocator.alloc(usize, allocSize);
    defer allocator.free(data);

    var prng = std.Random.DefaultPrng.init(val: {
        const now = Io.Clock.real.now(io);
        break :val @intCast(now.toMicroseconds());
    });
    const rng = prng.random();

    try printHeader(w);
    for (0..iters) |it| {
        try w.print("{d},", .{it + 1});
        for (algs) |alg| {
            rng.bytes(std.mem.sliceAsBytes(data));
            const duration = sorter.measure(io, alg.name, alg.alg, data);
            try w.print("{d} ms,", .{duration.toMilliseconds()});
        }
        try w.writeByte('\n');
        try w.flush();
    }
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();

    const cli = try sorter.CliArgs.parse(&args);

    var file = try createFile(init.io, cli.outCsv);
    defer file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var writer = file.writerStreaming(init.io, &buffer);

    if (cli.minArraySize) |min| {
        try iterate(init.io, &writer.interface, cli.iterations, min);
    }

    if (cli.midArraySize) |mid| {
        try iterate(init.io, &writer.interface, cli.iterations, mid);
    }

    if (cli.maxArraySize) |max| {
        try iterate(init.io, &writer.interface, cli.iterations, max);
    }

    try writer.interface.flush();
}
