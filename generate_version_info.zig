const std = @import("std");
const fmt = @import("std").fmt;

pub fn main() !void {
   var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
   defer arena_state.deinit();
   const arena = arena_state.allocator();
   const args = try std.process.argsAlloc(arena);

   if (args.len < 5) {
      gen.fatal("wrong number of arguments provided", .{});
   }

   const output_file_path = args[1];

   var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
      gen.fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
   };
   defer output_file.close();

   var buffer: [100]u8 = undefined;
   const output_string = try fmt.bufPrint(
      buffer[0..],
      \\ pub const Major = {s};
      \\ pub const Minor = {s};
      \\ pub const Patch = {s};
      \\ pub const PreRelease = {s};
      ,
      .{ args[2], args[3], args[4], args[5] }
   );

   try output_file.writeAll(output_string);

   return std.process.cleanExit();
}

// IMPORTS //

const gen = @import("generators.zig");
