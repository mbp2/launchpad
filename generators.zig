pub fn fatal(comptime format: []const u8, arguments: anytype) noreturn {
   std.debug.print(format, arguments);
   std.process.exit(1);
}

// IMPORTS //

const std = @import("std");
