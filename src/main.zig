const std = @import("std");
const lru = @import("lru.zig");

comptime {
    _ = @import("basic.zig");
    _ = @import("linkedlist.zig");
    _ = @import("TwoQueueCache.zig");
}

pub fn benchmark(allocator: std.mem.Allocator, size: usize, comptime count: usize) !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();
    var trace = std.mem.zeroes([count]u64);

    for (0..trace.len) |i| {
        trace[i] = rand.intRangeAtMost(u64, 0, std.math.maxInt(u64)) % (size * 2);
    }

    var basic_lru = lru.LRUCache(u64, u64).init(
        allocator,
        size,
    );
    defer basic_lru.deinit();

    var hits: u64 = 0;
    var misses: u64 = 0;
    for (0..trace.len) |i| {
        if (i % 2 == 0) {
            try basic_lru.put(trace[i], trace[i]);
        } else {
            if (basic_lru.get(trace[i])) |_| {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try benchmark(allocator, 1000, 100000);
}

test {
    std.testing.refAllDecls(@This());
}
