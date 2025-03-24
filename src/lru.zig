const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linkedlist.zig").LinkedList;
const LinkedListNode = @import("linkedlist.zig").Node;

pub fn LRUCache(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoArrayHashMap(K, V),
        list: LinkedList(K),
        capacity: usize,

        const Self = @This();
        pub fn init(
            allocator: Allocator,
            cap: usize,
        ) Self {
            return Self{ .list = LinkedList(K){}, .map = std.AutoArrayHashMap(K, V).init(allocator), .capacity = cap };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            try self.map.put(key, value);
        }

        pub fn get(self: *Self, key: K) ?V {
            return self.map.get(key);
        }
    };
}

test "simple get add test" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 12);
    defer cache.deinit();
    try cache.put(5, 5);
    try cache.put(3, 6);

    try std.testing.expectEqual(@as(u8, 5), cache.get(5));
    try std.testing.expectEqual(@as(u8, 6), cache.get(3));
}
