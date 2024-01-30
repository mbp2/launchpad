pub fn main() !void {
   var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
   defer arena_state.deinit();
   const arena = arena_state.allocator();
   const file_path = "concat.zig";
   const output_file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
      gen.fatal("unable to open '{s}': {s}", .{ file_path, @errorName(err) });
   };
   defer output_file.close();

   const combinations = .{
      [2]u8 {1, 8},
      [2]u8 {1, 9},
      [2]u8 {2, 1},
      [2]u8 {2, 2},
      [2]u8 {4, 3},
      [2]u8 {16, 7},
      [2]u8 {23, 8},
      [2]u8 {31, 9},
      [2]u8 {40, 9},
      [2]u8 {49, 9},
      [2]u8 {58, 10},
      [2]u8 {68, 10},
      [2]u8 {78, 1},
      [2]u8 {79, 9},
      [2]u8 {88, 9},
      [2]u8 {97, 9},
      [2]u8 {106, 9},
      [2]u8 {115, 9},
   };

   var code: [*]u8 = undefined;
   var a = std.ArrayList([*]u8).init(arena);
   var b = std.ArrayList([*]u8).init(arena);
   defer a.deinit();
   defer b.deinit();

   for (combinations) |combo| {

      for (0..combo[0]) |idx| {
         var buffer: [25]u8 = undefined;
         a.append(try fmt.bufPrint(buffer[0..], "a[{d}]", .{ idx }));
      }

      for (0..combo[1]) |idx| {
         var buffer: [25]u8 = undefined;
         b.append(try fmt.bufPrint(buffer[0..], "b[{d}]", .{ idx }));
      }

      var buffer: [10000]u8 = undefined;
      code += try fmt.bufPrint(
         buffer[0..],
         \\ pub fn concat_{0d}_{1d}(a: [{0d}]u8, b: [{1d}]u8) [{0d} + {1d}]u8 {
         \\    return [{0d} + {1d}]u8 {
         \\       {2s:','}, {3s:','}
         \\    };
         \\ }
         ,
         .{
            combo[0], combo[1],
            a.items, b.items
         }
      );
   }

   try output_file.writeAll(code);
   return std.process.cleanExit();
}

// IMPORTS //

const gen = @import("generators.zig");
const std = @import("std");
const fmt = @import("std").fmt;
