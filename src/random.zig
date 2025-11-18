const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn RandomCache(comptime K: type, comptime V: type) type {
    const Item = struct { key: K, value: V };
    return struct {
        map: std.AutoArrayHashMap(K, Item),
        capacity: usize,
        allocator: Allocator,
        count: usize = 0,
        rng_state: u64,

        const Self = @This();
        pub fn init(allocator: Allocator, cap: usize) Self {
            var seed_material = std.time.nanoTimestamp();
            const seed = std.hash.Wyhash.hash(0, std.mem.asBytes(&seed_material));
            return Self{
                .map = std.AutoArrayHashMap(K, Item).init(allocator),
                .capacity = cap,
                .allocator = allocator,
                .rng_state = if (seed == 0) 0xdeadbeefcafebabe else seed,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn len(self: *Self) usize { return self.count; }

        fn nextIndex(self: *Self, upper: usize) usize {
            self.rng_state +%= 0x9E3779B97F4A7C15;
            var z = self.rng_state;
            z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
            z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
            z ^= z >> 31;
            return @intCast(z % @as(u64, upper));
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            if (self.map.getPtr(key)) |entry| {
                entry.value = value;
                return;
            }

            if (self.count >= self.capacity) {
                // TODO: Record which keys get evicted to validate distribution quality.
                var keys = try self.allocator.alloc(K, self.count);
                defer self.allocator.free(keys);
                var idx: usize = 0;
                var it = self.map.iterator();
                while (it.next()) |entry| {
                    keys[idx] = entry.key_ptr.*;
                    idx += 1;
                }
                const pick = self.nextIndex(keys.len);
                if (self.map.swapRemove(keys[pick])) {
                    self.count -= 1;
                }
            }

            try self.map.put(key, .{ .key = key, .value = value });
            self.count += 1;
        }

        pub fn get(self: *Self, key: K) ?V {
            if (self.map.get(key)) |v| {
                return v.value;
            }
            return null;
        }

        pub fn remove(self: *Self, key: K) bool {
            if (self.map.swapRemove(key)) {
                self.count -= 1;
                return true;
            }
            return false;
        }

        pub fn purge(self: *Self) void {
            self.map.clearAndFree();
            self.count = 0;
        }
    };
}

test "random basic" {
    var cache = RandomCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 1);
    try cache.put(2, 2);
    try cache.put(3, 3);
    try std.testing.expectEqual(@as(u8, 3), cache.get(3));
}

test "random overwrite keeps length" {
    var cache = RandomCache(u8, u8).init(std.testing.allocator, 1);
    defer cache.deinit();
    try cache.put(1, 5);
    try cache.put(1, 9);
    try std.testing.expectEqual(1, cache.len());
    try std.testing.expectEqual(@as(u8, 9), cache.get(1));
}

test "random remove and purge" {
    var cache = RandomCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 11);
    try cache.put(2, 22);
    try std.testing.expect(cache.remove(1));
    try std.testing.expectEqual(1, cache.len());
    try std.testing.expectEqual(null, cache.get(1));
    cache.purge();
    try std.testing.expectEqual(0, cache.len());
    try std.testing.expectEqual(null, cache.get(2));
}
