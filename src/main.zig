const std = @import("std");
const lru = @import("lru.zig");

comptime {
    _ = @import("basic.zig");
    _ = @import("linkedlist.zig");
    _ = @import("TwoQueueCache.zig");
}

pub fn benchmark(allocator: std.mem.Allocator, size: usize, count: usize) !void {
    var rng_state = blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    };

    const nextRand = struct {
        fn next(state: *u64) u64 {
            state.* +%= 0x9E3779B97F4A7C15;
            var z = state.*;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
            return z ^ (z >> 31);
        }
    }.next;
    const trace = try allocator.alloc(u64, count);
    defer allocator.free(trace);

    for (trace, 0..) |*slot, idx| {
        _ = idx;
        slot.* = nextRand(&rng_state) % (size * 2);
    }

    // TODO: Add an option to benchmark multiple cache strategies in one run.
    var basic_lru = lru.LRUCache(u64, u64).init(
        allocator,
        size,
    );
    defer basic_lru.deinit();

    var hits: u64 = 0;
    var misses: u64 = 0;
    for (trace, 0..) |value, idx| {
        if (idx % 2 == 0) {
            try basic_lru.put(value, value);
        } else {
            if (basic_lru.get(value)) |_| {
                hits += 1;
            } else {
                misses += 1;
            }
        }
    }
    std.debug.print("\nbasic lru benchmark [{}, {}]\n", .{
        size,
        count,
    });
    std.debug.print("\nhits: {}, misses: {}, ratio: {d:8.10}\n", .{ hits, misses, @as(f64, @floatFromInt(hits)) / @as(f64, @floatFromInt(hits + misses)) });
}

const ArgSettings = struct {
    size: usize = 1000,
    count: usize = 100000,
};

const ParseError = error{
    MissingValue,
    InvalidValue,
    HelpRequested,
};

fn parseArgs(allocator: std.mem.Allocator) !ArgSettings {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    var settings = ArgSettings{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            const value = args.next() orelse return ParseError.MissingValue;
            settings.size = std.fmt.parseInt(usize, value, 10) catch return ParseError.InvalidValue;
        } else if (std.mem.eql(u8, arg, "--count")) {
            const value = args.next() orelse return ParseError.MissingValue;
            settings.count = std.fmt.parseInt(usize, value, 10) catch return ParseError.InvalidValue;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else {
            std.debug.print("unknown flag: {s}\n", .{arg});
            return ParseError.InvalidValue;
        }
    }

    return settings;
}

fn printUsage() void {
    std.debug.print(
        "usage: zig run src/main.zig -- [--size <entries>] [--count <ops>]\\n",
        .{},
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.log.warn("general purpose allocator leaked", .{});
    }

    const allocator = gpa.allocator();
    const settings = parseArgs(allocator) catch |err| {
        switch (err) {
            ParseError.HelpRequested => {
                printUsage();
                return;
            },
            ParseError.MissingValue => {
                std.debug.print("flag requires a numeric value\n", .{});
                printUsage();
            },
            ParseError.InvalidValue => {
                std.debug.print("flags must be followed by unsigned integers\n", .{});
                printUsage();
            },
        }
        return err;
    };

    try benchmark(allocator, settings.size, settings.count);
}

test {
    std.testing.refAllDecls(@This());
}
