const std = @import("std");

const Args = std.process.Args.Iterator;
const eql = std.mem.eql;
const Io = std.Io;

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

pub const CliArgs = struct {
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

