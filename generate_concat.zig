pub fn main() !void {
   var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
   defer arena_state.deinit();
   const arena = arena_state.allocator();
   const args = try std.process.argsAlloc(arena);
   const file_path = args[1];
   const output_file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
      gen.fatal("unable to open '{s}': {s}", .{ file_path, @errorName(err) });
   };
   defer output_file.close();

   const combinations = .{
      .{ 1, 8 },
      .{ 1, 9 },
      .{ 2, 1 },
      .{ 2, 2 },
      .{ 4, 3 },
      .{ 16, 7 },
      .{ 23, 8 },
      .{ 31, 9 },
      .{ 40, 9 },
      .{ 49, 9 },
      .{ 58, 10 },
      .{ 68, 10 },
      .{ 78, 1 },
      .{ 79, 9 },
      .{ 88, 9 },
      .{ 97, 9 },
      .{ 106, 9 },
      .{ 115, 9 },
   };

   var code = std.ArrayList(u8).init(arena);
   var a = std.ArrayList(u8).init(arena);
   var b = std.ArrayList(u8).init(arena);
   defer a.deinit();
   defer b.deinit();

   inline for (combinations) |combo| {
      for (0..combo[0]) |idx| {
         var buffer: [100]u8 = undefined;
         const result = fmt.bufPrint(buffer[0..], "a[{d}]", .{ idx }) catch |err| {
            gen.fatal("unable to write {s} to buffer: {s}", .{ buffer, @errorName(err) });
         };

         try a.appendSlice(result);
      }

      for (0..combo[1]) |idx| {
         var buffer: [100]u8 = undefined;
         const result = fmt.bufPrint(buffer[0..], "b[{d}]", .{ idx }) catch |err| {
            gen.fatal("unable to write {s} to buffer: {s}", .{ buffer, @errorName(err) });
         };

         try b.appendSlice(result);
      }

      var buffer: [100000]u8 = undefined;
      var c = std.ArrayList(u8).init(arena);
      defer c.deinit();
      try c.appendSlice(a.items);
      try c.appendSlice(b.items);

      const result = try fmt.bufPrint(
         buffer[0..],
         \\ pub fn concat_{0d}_{1d}(a: [{0d}]u8, b: [{1d}]u8) [{0d} + {1d}]u8 {{
         \\    return [{0d} + {1d}]u8
         \\       {2d:,>}
         \\    ;
         \\ }}
         ,
         .{
            combo[0], combo[1],
            c.items
         }
      );

      try code.appendSlice(result);
   }

   try output_file.writeAll(code.items);
   return std.process.cleanExit();
}

// IMPORTS //

const gen = @import("generators.zig");
const std = @import("std");
const fmt = @import("std").fmt;
