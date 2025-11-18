const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linkedlist.zig").LinkedList;
const Node = @import("linkedlist.zig").Node;

pub fn FIFOCache(comptime K: type, comptime V: type) type {
    const CacheValue = struct { key: K, value: V };
    return struct {
        map: std.AutoHashMap(K, *Node(CacheValue)),
        list: LinkedList(CacheValue),
        size: usize,
        allocator: Allocator,

        const Self = @This();
        pub fn init(allocator: Allocator, init_size: usize) Self {
            const map = std.AutoHashMap(K, *Node(CacheValue)).init(allocator);
            return Self{ .list = LinkedList(CacheValue){}, .map = map, .size = init_size, .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.purge();
            self.map.deinit();
        }

        pub fn len(self: *Self) usize {
            return self.list.len;
        }

        pub fn evictOldest(self: *Self) void {
            const oldest = self.list.popTail();
            if (oldest) |node| {
                _ = self.map.remove(node.val.key);
                self.allocator.destroy(node);
            }
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            if (self.map.get(key)) |ptr| {
                ptr.*.val.value = value;
            } else {
                if (self.list.len >= self.size) {
                    self.evictOldest();
                }

                const node = try self.allocator.create(Node(CacheValue));
                node.val.value = value;
                node.val.key = key;

                try self.map.put(key, node);
                self.list.pushHead(node);
            }
        }

        pub fn get(self: *Self, key: K) ?V {
            if (self.map.get(key)) |ptr| {
                return ptr.val.value;
            } else {
                return null;
            }
        }

        pub fn remove(self: *Self, key: K) void {
            if (self.map.get(key)) |ptr| {
                _ = self.map.remove(key);
                self.list.remove(ptr);
                self.allocator.destroy(ptr);
            }
        }

        pub fn purge(self: *Self) void {
            while (self.list.popTail()) |node| {
                self.allocator.destroy(node);
            }
            self.map.clearAndFree();
        }
    };
}

test "fifo basic" {
    var cache = FIFOCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 10);
    try cache.put(2, 20);
    try cache.put(3, 30);

    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(@as(u8, 20), cache.get(2));
    try std.testing.expectEqual(@as(u8, 30), cache.get(3));
}
