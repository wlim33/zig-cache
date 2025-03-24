const std = @import("std");

comptime {
    _ = @import("basic.zig");
    _ = @import("lru.zig");
    _ = @import("linkedlist.zig");
}

test {
    std.testing.refAllDecls(@This());
}
