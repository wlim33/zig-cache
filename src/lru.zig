const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linkedlist.zig").LinkedList;
const Node = @import("linkedlist.zig").Node;

pub fn LRUCache(comptime K: type, comptime V: type) type {
    const CacheValue = struct { key: K, value: V };
    return struct {
        map: std.AutoHashMap(K, *Node(CacheValue)),
        list: LinkedList(CacheValue),
        size: usize,
        allocator: Allocator,
        on_evict: OnEvictOp = defaultOnEvict,

        const OnEvictOp = *const fn (k: K, v: V) void;
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

        pub fn evictLeastUsed(self: *Self) void {
            const leastUsed = self.list.popTail();
            if (self.map.remove(leastUsed.?.val.key)) {
                self.on_evict(leastUsed.?.val.key, leastUsed.?.val.value);
                self.allocator.destroy(leastUsed.?);
            }
        }

        pub fn remove(self: *Self, key: K) void {
            if (self.map.get(key)) |ptr| {
                _ = self.map.remove(key);
                self.list.remove(ptr);
                self.allocator.destroy(ptr);
            } else {
                return null;
            }
        }

        pub fn peek(self: *Self, key: K) ?V {
            if (self.map.get(key)) |ptr| {
                return ptr.val.value;
            } else {
                return null;
            }
        }

        pub fn contains(self: *Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn purge(self: *Self) void {
            while (self.list.popTail()) |node| {
                self.allocator.destroy(node);
            }
            self.map.clearAndFree();
        }

        pub fn resize(self: *Self, new_size: usize) usize {
            const diff = if (new_size > self.size) 0 else self.size - new_size;
            for (0..diff) |_| {
                self.evictLeastUsed();
            }

            self.size = new_size;
            return diff;
        }

        pub fn getOldest(self: *Self) ?V {
            return self.list.tail.?.*.val.value;
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            if (self.map.get(key)) |ptr| {
                ptr.*.val.value = value;
                self.list.remove(ptr);
                self.list.pushHead(ptr);
            } else {
                if (self.list.len >= self.size) {
                    self.evictLeastUsed();
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
                self.list.remove(ptr);
                self.list.pushHead(ptr);
                return ptr.val.value;
            } else {
                return null;
            }
        }
        pub fn defaultOnEvict(_: K, _: V) void {}
    };
}

test "simple get add test" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(5, 5);

    try std.testing.expectEqual(1, cache.len());
    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(@as(u8, 5), cache.get(5));
}
test "add overwrite within capacity" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(5, 7);

    try std.testing.expectEqual(1, cache.len());
    try std.testing.expectEqual(null, cache.get(1));
    try std.testing.expectEqual(@as(u8, 7), cache.get(5));
}

test "add evict" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 1);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);

    try std.testing.expectEqual(1, cache.len());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
}

test "add evict 2" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
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

    try std.testing.expectEqual(4, cache.len());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
    try std.testing.expectEqual(@as(u8, 9), cache.get(8));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
    try std.testing.expectEqual(@as(u8, 12), cache.get(1));
}

test "add evict get" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);
    try cache.put(1, 12);

    try std.testing.expectEqual(4, cache.len());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));

    try cache.put(13, 14);
    try std.testing.expectEqual(null, cache.get(8));
    try std.testing.expectEqual(@as(u8, 14), cache.get(13));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
    try std.testing.expectEqual(@as(u8, 12), cache.get(1));
}

test "resize smaller" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);

    try std.testing.expectEqual(4, cache.len());
    try std.testing.expectEqual(2, cache.resize(2));

    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(null, cache.get(6));
    try std.testing.expectEqual(@as(u8, 9), cache.get(8));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
}

test "resize bigger" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);

    try std.testing.expectEqual(4, cache.len());
    try std.testing.expectEqual(0, cache.resize(12));

    try std.testing.expectEqual(@as(u8, 3), cache.get(5));
    try std.testing.expectEqual(@as(u8, 7), cache.get(6));
    try std.testing.expectEqual(@as(u8, 9), cache.get(8));
    try std.testing.expectEqual(@as(u8, 2), cache.get(11));
}

test "purge" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);
    cache.purge();

    try std.testing.expectEqual(0, cache.len());
    try std.testing.expectEqual(null, cache.get(5));
    try std.testing.expectEqual(null, cache.get(6));
    try std.testing.expectEqual(null, cache.get(8));
    try std.testing.expectEqual(null, cache.get(11));
}

test "peek" {
    var cache = LRUCache(u8, u8).init(std.testing.allocator, 4);
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);

    try std.testing.expectEqual(3, cache.peek(5));
    try std.testing.expectEqual(1, cache.resize(3));
    try std.testing.expectEqual(null, cache.get(5));
}

test "evict last" {
    var cache = LRUCache(u8, u8).init(
        std.testing.allocator,
        4,
    );
    defer cache.deinit();
    try cache.put(5, 3);
    try cache.put(6, 7);
    try cache.put(8, 9);
    try cache.put(11, 2);

    try std.testing.expectEqual(3, cache.peek(5));
    cache.evictLeastUsed();
    try std.testing.expectEqual(null, cache.get(5));
}
