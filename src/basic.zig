const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = error{
    AddError,
};

pub fn Cache(comptime K: type, comptime V: type) type {
    const Item = struct {
        v: V,
        expiration: i128,

        const Self = @This();
        fn expired(self: Self) bool {
            return self.expiration > 0 and std.time.nanoTimestamp() > self.expiration;
        }
    };
    return struct {
        backing: std.AutoArrayHashMap(K, Item),
        capacity: usize,

        const Self = @This();
        fn set(self: *Self, key: K, value: V, d: i128) !void {
            const expiration = if (d >= 0) std.time.nanoTimestamp() + d else -1;
            try self.backing.put(key, .{ .v = value, .expiration = expiration });
        }

        fn delete(self: *Self, key: K) bool {
            return self.backing.remove(key);
        }

        fn deleteExpired(self: *Self) void {
            const now = std.time.nanoTimestamp();
            for (self.backing.keys()) |key| {
                if (self.backing.get(key)) |item| {
                    if (item.expiration > now) {
                        std.debug.assert(self.backing.swapRemove(key));
                    }
                }
            }
        }

        fn get(self: *Self, key: K) ?V {
            if (self.backing.get(key)) |item| {
                if (item.expiration < 0 or !item.expired()) {
                    return item.v;
                }
            }
            return null;
        }

        pub fn init(
            allocator: Allocator,
            cap: usize,
        ) Self {
            return Self{ .backing = std.AutoArrayHashMap(K, Item).init(allocator), .capacity = cap };
        }

        pub fn deinit(self: *Self) void {
            self.backing.deinit();
        }
    };
}

test "example test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(12);
    try std.testing.expectEqual(@as(i32, 12), list.pop());
}

test "delete expired test" {
    var cache = Cache(u8, u8).init(std.testing.allocator, 12);
    defer cache.deinit();
    try cache.set(5, 5, 1);
    try cache.set(1, 5, 1);
    try cache.set(2, 5, 1);
    try cache.set(3, 5, 1);

    cache.deleteExpired();
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(null, cache.get(2));
    try std.testing.expectEqual(null, cache.get(3));
}

test "add get test" {
    var cache = Cache(u8, u8).init(std.testing.allocator, 12);
    defer cache.deinit();
    try cache.set(5, 5, -1);

    try std.testing.expectEqual(@as(u8, 5), cache.get(5));
}
