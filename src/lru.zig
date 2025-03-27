const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linkedlist.zig").LinkedList;
const Node = @import("linkedlist.zig").Node;

pub fn LRUCache(comptime K: type, comptime V: type) type {
    const CacheValue = struct { key: K, value: V };
    return struct {
        map: std.AutoHashMap(K, Node(CacheValue)),

        allocator: std.mem.Allocator,
        list: LinkedList(CacheValue),
        capacity: usize,

        const Self = @This();
        pub fn init(
            allocator: Allocator,
            cap: usize,
        ) !Self {
            const map = std.AutoHashMap(K, Node(CacheValue)).init(allocator);
            return Self{ .list = LinkedList(CacheValue){}, .map = map, .capacity = cap, .allocator = allocator };
        }

        pub fn size(self: *Self) usize {
            return self.list.len;
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            const entry = try self.map.getOrPut(key);
            if (entry.found_existing) {
                entry.value_ptr.*.val.value = value;
                self.list.remove(entry.value_ptr);
                self.list.pushHead(entry.value_ptr);
            } else {
                if (self.list.len >= self.capacity) {
                    const leastUsed = self.list.popTail();
                    _ = self.map.remove(leastUsed.?.val.key);
                }

                entry.value_ptr.* = Node(CacheValue){ .val = .{ .key = key, .value = value } };
                self.list.pushHead(entry.value_ptr);
            }
        }

        pub fn get(self: *Self, key: K) ?V {
            if (self.map.getPtr(key)) |ptr| {
                self.list.remove(ptr);
                self.list.pushHead(ptr);
                return ptr.*.val.value;
            } else {
                return null;
            }
        }
    };
}

test "simple get add test" {
    var cache = try LRUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(5, 5);

    try std.testing.expectEqual(1, cache.size());
    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(@as(u8, 5), cache.get(5));
}
test "add overwrite within capacity" {
    var cache = try LRUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(5, 7);

    try std.testing.expectEqual(1, cache.size());
    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(@as(u8, 7), cache.get(5));
}

test "add evict" {
    var cache = try LRUCache(u8, u8).init(std.testing.allocator, 1);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);

    try std.testing.expectEqual(1, cache.size());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
}

test "add evict 2" {
    var cache = try LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try std.testing.expectEqual(@as(u8, 5), cache.list.head.?.val.key);
    try std.testing.expectEqual(@as(u8, 5), cache.list.tail.?.val.key);
    try std.testing.expectEqual(@as(u8, 1), cache.list.len);
    try cache.put(6, 7);

    try std.testing.expectEqual(@as(u8, 2), cache.list.len);
    try std.testing.expectEqual(@as(u8, 6), cache.list.head.?.val.key);
    try std.testing.expectEqual(@as(u8, 5), cache.list.tail.?.val.key);
    try cache.put(8, 9);
    try cache.put(11, 2);

    try cache.put(1, 12);

    try std.testing.expectEqual(4, cache.size());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
    try std.testing.expectEqual(@as(u8, 9), cache.get(8));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
    try std.testing.expectEqual(@as(u8, 12), cache.get(1));
}

test "add evict get" {
    var cache = try LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);
    try cache.put(1, 12);

    try std.testing.expectEqual(4, cache.size());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));

    try cache.put(13, 14);
    try std.testing.expectEqual(null, cache.get(8));
    try std.testing.expectEqual(@as(u8, 14), cache.get(13));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
    try std.testing.expectEqual(@as(u8, 12), cache.get(1));
}
