pub fn Spinlock(comptime T: anytype) type {
    return struct {
        inner: T,
    };
}
