const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linkedlist.zig").LinkedList;
const Node = @import("linkedlist.zig").Node;

pub fn ClockCache(comptime K: type, comptime V: type) type {
    const CacheValue = struct { key: K, value: V, referenced: bool };
    return struct {
        map: std.AutoHashMap(K, *Node(CacheValue)),
        list: LinkedList(CacheValue),
        hand: ?*Node(CacheValue) = null,
        capacity: usize,
        allocator: Allocator,

        const Self = @This();
        pub fn init(allocator: Allocator, cap: usize) Self {
            return Self{ .map = std.AutoHashMap(K, *Node(CacheValue)).init(allocator), .list = LinkedList(CacheValue){}, .hand = null, .capacity = cap, .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.purge();
            self.map.deinit();
        }

        fn advanceHand(self: *Self) void {
            if (self.hand) |h| {
                if (h.next) |n| {
                    self.hand = n;
                } else {
                    self.hand = self.list.head;
                }
            } else {
                self.hand = self.list.head;
            }
        }

        fn evictOne(self: *Self) void {
            // TODO: Allow configuring multiple second-chance sweeps before eviction.
            if (self.list.len == 0) return;
            if (self.hand == null) {
                self.hand = self.list.head;
            }

            while (true) {
                if (self.hand) |h| {
                    if (h.val.referenced) {
                        h.val.referenced = false;
                        self.advanceHand();
                        continue;
                    } else {
                        const victim = h;
                        const key = victim.val.key;
                        self.advanceHand();
                        self.list.remove(victim);
                        _ = self.map.remove(key);
                        self.allocator.destroy(victim);
                        break;
                    }
                } else {
                    break;
                }
            }
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            if (self.map.get(key)) |ptr| {
                ptr.*.val.value = value;
                ptr.*.val.referenced = true;
                return;
            }

            if (self.list.len >= self.capacity) {
                self.evictOne();
            }

            const node = try self.allocator.create(Node(CacheValue));
            node.val.key = key;
            node.val.value = value;
            node.val.referenced = true;
            try self.map.put(key, node);
            self.list.pushHead(node);
            self.hand = node;
        }

        pub fn get(self: *Self, key: K) ?V {
            if (self.map.get(key)) |ptr| {
                ptr.*.val.referenced = true;
                return ptr.val.value;
            }
            return null;
        }

        pub fn remove(self: *Self, key: K) void {
            if (self.map.get(key)) |ptr| {
                _ = self.map.remove(key);
                self.list.remove(ptr);
                self.allocator.destroy(ptr);
            }
        }

        pub fn purge(self: *Self) void {
            while (self.list.popTail()) |node| { self.allocator.destroy(node); }
            self.map.clearAndFree();
            self.hand = null;
        }
    };
}

test "clock basic" {
    var cache = ClockCache(u8, u8).init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put(1, 1);
    try cache.put(2, 2);
    _ = cache.get(1);
    try cache.put(3, 3);
    try std.testing.expectEqual(@as(u8, 1), cache.get(1));
}
