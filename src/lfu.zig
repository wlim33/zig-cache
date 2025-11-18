const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn LFUCache(comptime K: type, comptime V: type) type {
    const Item = struct { key: K, value: V, freq: usize };
    return struct {
        map: std.AutoHashMap(K, Item),
        capacity: usize,
        allocator: Allocator,
        len: usize = 0,

        const Self = @This();
        pub fn init(allocator: Allocator, cap: usize) Self {
            return Self{ .map = std.AutoHashMap(K, Item).init(allocator), .capacity = cap, .allocator = allocator };
        }

        pub fn deinit(self: *Self) void { self.map.deinit(); }

        fn evictLeastFrequent(self: *Self) void {
            var candidate_key: ?K = null;
            var min_freq: usize = std.math.maxInt(usize);
            var it = self.map.iterator();
            while (it.next()) |entry| {
                const freq = entry.value_ptr.*.freq;
                if (freq < min_freq) {
                    min_freq = freq;
                    candidate_key = entry.key_ptr.*;
                }
            }
                if (candidate_key) |ck| {
                    if (self.map.remove(ck)) {
                        self.len -= 1;
                    }
            }
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            if (self.map.getPtr(key)) |entry| {
                entry.value = value;
                entry.freq += 1;
                return;
            }

            if (self.len >= self.capacity) {
                self.evictLeastFrequent();
            }
            try self.map.put(key, .{ .key = key, .value = value, .freq = 1 });
            self.len += 1;
        }

        pub fn get(self: *Self, key: K) ?V {
            if (self.map.getPtr(key)) |entry| {
                entry.freq += 1;
                return entry.value;
            }
            return null;
        }

        pub fn remove(self: *Self, key: K) bool {
            if (self.map.remove(key)) {
                self.len -= 1;
                return true;
            }
            return false;
        }

        pub fn purge(self: *Self) void {
            self.map.clearAndFree();
            self.len = 0;
        }
    };
}

test "lfu basic" {
    var cache = LFUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 1);
    try cache.put(2, 2);
    _ = cache.get(1);
    try cache.put(3, 3);
    try std.testing.expectEqual(null, cache.get(2));
    try std.testing.expectEqual(@as(u8, 1), cache.get(1));
    try std.testing.expectEqual(@as(u8, 3), cache.get(3));
}

test "lfu overwrite bumps freq" {
    var cache = LFUCache(u8, u8).init(std.testing.allocator, 1);
    defer cache.deinit();
    try cache.put(5, 10);
    try cache.put(5, 20);
    try std.testing.expectEqual(1, cache.len);
    try std.testing.expectEqual(@as(u8, 20), cache.get(5));
    try std.testing.expectEqual(@as(u8, 20), cache.get(5));
}

test "lfu remove and purge" {
    var cache = LFUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 10);
    try cache.put(2, 20);
    try std.testing.expect(cache.remove(1));
    try std.testing.expectEqual(@as(?u8, null), cache.get(1));
    try std.testing.expectEqual(@as(usize, 1), cache.len);
    cache.purge();
    try std.testing.expectEqual(@as(usize, 0), cache.len);
    try std.testing.expectEqual(@as(?u8, null), cache.get(2));
}
