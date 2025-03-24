const std = @import("std");

pub fn Node(comptime T: type) type {
    return struct {
        const Self = @This();
        val: T,
        before: ?*Self = null,
        next: ?*Self = null,

        pub fn clearReferences(self: *Self) void {
            self.before = null;
            self.next = null;
        }
    };
}

pub fn LinkedList(comptime T: type) type {
    const Iterator = struct {
        current: ?*Node(T),
        const Self = @This();
        pub fn next(self: *Self) ?*const Node(T) {
            const oldCurrent = self.current;
            if (oldCurrent) |cur| {
                self.current = cur.next;
            }
            return oldCurrent;
        }
    };

    const TailIterator = struct {
        current: ?*Node(T),
        const Self = @This();
        pub fn next(self: *Self) ?*const Node(T) {
            const oldCurrent = self.current;
            if (oldCurrent) |cur| {
                self.current = cur.before;
            }
            return oldCurrent;
        }
    };

    return struct {
        head: ?*Node(T) = null,
        tail: ?*Node(T) = null,
        len: usize = 0,
        const Self = @This();

        pub fn pushHead(self: *Self, ptr: *Node(T)) void {
            ptr.clearReferences();
            self.len += 1;

            if (self.head) |old_head| {
                ptr.next = old_head;
                old_head.before = ptr;
                self.head = ptr;
            } else {
                self.head = ptr;
                self.tail = ptr;
            }
        }

        pub fn pushTail(self: *Self, ptr: *Node(T)) void {
            ptr.clearReferences();
            self.len += 1;

            if (self.tail) |old_tail| {
                ptr.before = old_tail;
                old_tail.next = ptr;
                self.tail = ptr;
            } else {
                self.head = ptr;
                self.tail = ptr;
            }
        }
        pub fn remove(self: *Self, node: *Node(T)) void {
            if (node == self.head) {
                _ = self.popHead();
                return;
            }
            if (node == self.tail) {
                _ = self.popTail();
                return;
            }
            self.len -= 1;
            if (node.next) |old_next| {
                old_next.before = node.before;
            }
            if (node.before) |old_before| {
                old_before.next = node.next;
            }
            node.clearReferences();
        }

        pub fn popTail(self: *Self) ?*Node(T) {
            if (self.len == 0) {
                return null;
            }

            if (self.len == 1) {
                const old_tail = self.tail.?;
                self.tail = null;
                self.head = null;

                self.len -= 1;
                old_tail.clearReferences();
                return old_tail;
            }

            const old_tail = self.tail.?;
            if (old_tail.before) |next_tail| {
                self.tail = next_tail;
                next_tail.next = null;
            } else {
                self.head = null;
                self.tail = null;
            }

            self.len -= 1;
            old_tail.clearReferences();
            return old_tail;
        }

        pub fn popHead(self: *Self) ?*Node(T) {
            if (self.len == 0) {
                return null;
            }

            if (self.len == 1) {
                const old_head = self.head.?;
                self.tail = null;
                self.head = null;

                self.len -= 1;
                old_head.clearReferences();
                return old_head;
            }

            const old_head = self.head.?;
            if (old_head.next) |next_head| {
                self.head = next_head;
                next_head.before = null;
            } else {
                self.head = null;
                self.tail = null;
            }

            self.len -= 1;
            old_head.clearReferences();
            return old_head;
        }

        pub fn tailIterate(self: *Self) TailIterator {
            return TailIterator{
                .current = self.tail,
            };
        }
        pub fn headIterate(self: *Self) Iterator {
            return Iterator{
                .current = self.head,
            };
        }
    };
}

fn checkForward(
    comptime T: type,
    values: []T,
    list: *LinkedList(T),
) !void {
    try std.testing.expectEqual(values.len, list.len);
    var iter = list.headIterate();
    var idx: usize = 0;
    while (iter.next()) |node| : (idx += 1) {
        try std.testing.expectEqual(values[idx], node.val);
    }
}

fn checkBackward(
    comptime T: type,
    values: []T,
    list: *LinkedList(T),
) !void {
    try std.testing.expectEqual(values.len, list.len);
    var iter = list.tailIterate();
    var idx: usize = list.len;
    while (iter.next()) |node| {
        idx -= 1;
        try std.testing.expectEqual(values[idx], node.val);
    }
}

fn checkBothDirections(
    comptime T: type,
    values: []T,
    list: *LinkedList(T),
) !void {
    try checkBackward(T, values, list);
    try checkForward(T, values, list);
}

test "basic init" {
    const ll: LinkedList(u8) = LinkedList(u8){};

    try std.testing.expectEqual(0, ll.len);
}

test "add head" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushHead(&n_1);

    try std.testing.expectEqual(1, ll.len);

    var n_2 = Node(u8){ .val = 2 };
    ll.pushHead(&n_2);

    try std.testing.expectEqual(2, ll.len);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushHead(&n_3);

    try std.testing.expectEqual(3, ll.len);
}

test "tail iterator" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    const l = [_]u8{ 1, 2, 3, 4, 5, 6 };

    const nodes: []Node(u8) = try std.testing.allocator.alloc(Node(u8), l.len);
    for (0.., l) |idx, num| {
        nodes[idx].val = num;
    }
    defer std.testing.allocator.free(nodes);

    for (nodes) |*node| {
        ll.pushHead(node);
    }

    try std.testing.expectEqual(l.len, ll.len);
    var iter = ll.tailIterate();
    var idx: usize = 0;
    while (iter.next()) |node| : (idx += 1) {
        try std.testing.expectEqual(l[idx], node.val);
    }

    try std.testing.expectEqual(l.len, ll.len);
}
test "head iterator" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    const l = [_]u8{ 1, 2, 3, 4, 5, 6 };

    const nodes: []Node(u8) = try std.testing.allocator.alloc(Node(u8), l.len);
    for (0.., l) |idx, num| {
        nodes[idx].val = num;
    }
    defer std.testing.allocator.free(nodes);

    for (nodes) |*node| {
        ll.pushHead(node);
    }

    try std.testing.expectEqual(l.len, ll.len);
    var iter = ll.headIterate();
    var idx: usize = l.len;

    while (iter.next()) |node| {
        idx -= 1;
        try std.testing.expectEqual(l[idx], node.val);
    }

    try std.testing.expectEqual(l.len, ll.len);
}

test "remove head" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushHead(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushHead(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushHead(&n_3);
    var n_4 = Node(u8){ .val = 4 };
    ll.pushHead(&n_4);

    try std.testing.expectEqual(4, ll.len);

    ll.remove(&n_4);
    try std.testing.expectEqual(3, ll.len);
    const l = [_]u8{ 3, 2, 1 };

    var iter = ll.headIterate();
    var idx: usize = 0;
    while (iter.next()) |node| : (idx += 1) {
        try std.testing.expectEqual(l[idx], node.val);
    }
}

test "remove middle" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushHead(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushHead(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushHead(&n_3);
    var n_4 = Node(u8){ .val = 4 };
    ll.pushHead(&n_4);

    try std.testing.expectEqual(4, ll.len);

    ll.remove(&n_3);
    try std.testing.expectEqual(3, ll.len);
    var l = [_]u8{ 4, 2, 1 };

    try checkBothDirections(u8, &l, &ll);
}

test "push head, pop tail (queue)" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushHead(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushHead(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushHead(&n_3);

    try std.testing.expectEqual(3, ll.len);

    var init_values = [_]u8{ 3, 2, 1 };
    try checkBothDirections(u8, &init_values, &ll);
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(1, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);

        var values = [_]u8{ 3, 2 };
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(2, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        var values = [_]u8{3};
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(3, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        try std.testing.expectEqual(0, ll.len);
        try std.testing.expectEqual(null, ll.head);
        try std.testing.expectEqual(null, ll.tail);
    }
}

test "push head, pop head (stack)" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushHead(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushHead(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushHead(&n_3);

    try std.testing.expectEqual(3, ll.len);

    var init_values = [_]u8{ 3, 2, 1 };
    try checkBothDirections(u8, &init_values, &ll);
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(3, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);

        var values = [_]u8{ 2, 1 };
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(2, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);

        var values = [_]u8{1};
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(1, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        try std.testing.expectEqual(0, ll.len);
        try std.testing.expectEqual(null, ll.head);
        try std.testing.expectEqual(null, ll.tail);
    }
}

test "push tail, pop tail (stack)" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushTail(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushTail(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushTail(&n_3);

    try std.testing.expectEqual(3, ll.len);

    var init_values = [_]u8{ 1, 2, 3 };
    try checkBothDirections(u8, &init_values, &ll);
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(3, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);

        var values = [_]u8{ 1, 2 };
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(2, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        var values = [_]u8{1};
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popTail()) |node| {
        try std.testing.expectEqual(1, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        try std.testing.expectEqual(0, ll.len);
        try std.testing.expectEqual(null, ll.head);
        try std.testing.expectEqual(null, ll.tail);
    }
}

test "push tail, pop head (queue)" {
    var ll: LinkedList(u8) = LinkedList(u8){};
    var n_1 = Node(u8){ .val = 1 };
    ll.pushTail(&n_1);
    var n_2 = Node(u8){ .val = 2 };
    ll.pushTail(&n_2);
    var n_3 = Node(u8){ .val = 3 };
    ll.pushTail(&n_3);

    try std.testing.expectEqual(3, ll.len);

    var init_values = [_]u8{ 1, 2, 3 };
    try checkBothDirections(u8, &init_values, &ll);
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(1, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);

        var values = [_]u8{ 2, 3 };
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(2, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        var values = [_]u8{3};
        try checkBothDirections(u8, &values, &ll);
    }
    if (ll.popHead()) |node| {
        try std.testing.expectEqual(3, node.val);
        try std.testing.expectEqual(null, node.before);
        try std.testing.expectEqual(null, node.next);
        try std.testing.expectEqual(0, ll.len);
        try std.testing.expectEqual(null, ll.head);
        try std.testing.expectEqual(null, ll.tail);
    }
}
