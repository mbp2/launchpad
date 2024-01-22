const builtin = @import("builtin");
const std = @import("std");

const fmt = std.fmt;
const uefi = std.os.uefi;

// Begin Protocols

var app: ?*uefi.protocols.AbsolutePointerProtocol = undefined;
var con: ?*uefi.protocols.SimpleTextOutputProtocol = undefined;
var gop: ?*uefi.protocols.GraphicsOutputProtocol = undefined;
var rng: ?*uefi.protocols.RNGProtocol = undefined;
var spp: ?*uefi.protocols.SimplePointerProtocol = undefined;

// End Protocols

// Begin Runtime

var descriptor_size: usize = undefined;
var descriptor_version: u32 = undefined;
var framebuffer: [*]u8 = undefined;
var mmap: [*]uefi.tables.MemoryDescriptor = undefined;
var mmap_size: usize = 0;
var mmap_key: usize = undefined;

// End Runtime

fn puts(msg: []const u8) void {
    for (msg) |c| {
        const c_ = [2]u16{ c, 0 }; // work around https://github.com/ziglang/zig/issues/4372
        _ = con.?.outputString(@as(*const [1:0]u16, @ptrCast(&c_)));
    }
}

fn printf(buf: []u8, comptime format: []const u8, args: anytype) void {
    puts(fmt.bufPrint(buf, format, args) catch unreachable);
}

pub fn main() void {
    const boot_services = uefi.system_table.boot_services.?;
    const runtime_services = uefi.system_table.runtime_services;

    var buf: [100]u8 = undefined;

    var buffer_size: usize = 2;
    var name: [*:0]align(8) u16 = undefined;
    _ = boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, 2, @as(*[*]align(8) u8, @ptrCast(&name)));
    name[0] = 0;
    var guid: uefi.Guid align(8) = undefined;

    if (boot_services.locateProtocol(&uefi.protocols.SimpleTextOutputProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&con))) == uefi.Status.Success) {
        puts("*** simple text output protocol is supported ***\r\n");

        // `con` is only null if no protocol support has been found;
        // list the device's supported output resolutions:
        var index: u32 = 0;
        while (index < con.?.mode.max_mode) : (index += 1) {
            var x: usize = undefined;
            var y: usize = undefined;

            // queryMode could fail on device error or if we request an invalid mode.
            _ = con.?.queryMode(index, &x, &y);
            printf(buf[0..], "    mode {} = {}x{}\r\n", .{ index, x, y });
        }
    } else {
        puts("*** simple text output protocol is NOT supported ***\r\n");
    }

    _ = boot_services.stall(3 * 1000);

    // Check if we have a relative pointing device (i.e. mouse, touchpad):
    if (boot_services.locateProtocol(&uefi.protocols.SimplePointerProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&spp))) == uefi.Status.Success) {
        puts("*** simple pointer protocol is supported ***\r\n");

        // Check the pointer resolution of the device:
        printf(buf[0..], "    resolution x = {} per millimetre\r\n", .{spp.?.mode.resolution_x});
        printf(buf[0..], "    resolution y = {} per millimetre\r\n", .{spp.?.mode.resolution_y});
        printf(buf[0..], "    resolution z = {} per millimetre\r\n", .{spp.?.mode.resolution_z});

        // Check if the pointer has buttons:
        if (spp.?.mode.left_button) {
            puts("    has left button\r\n");
        } else {
            puts("    left button not found\r\n");
        }

        if (spp.?.mode.right_button) {
            puts("    has right button\r\n");
        } else {
            puts("    right button not found\r\n");
        }
    } else {
        puts("*** simple pointer protocol is NOT supported ***\r\n");
    }

    _ = boot_services.stall(3 * 1000);

    // Check if we have an absolute pointing device (i.e. touchscreen):
    if (boot_services.locateProtocol(&uefi.protocols.AbsolutePointerProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&app))) == uefi.Status.Success) {
        puts("*** absolute pointer protocol is supported ***\r\n");

        // Check the pointer resolution of the device:
        printf(buf[0..], "    minimum resolution x = {} per millimetre\r\n", .{app.?.mode.absolute_min_x});
        printf(buf[0..], "    maximum resolution x = {} per millimetre\r\n", .{app.?.mode.absolute_max_x});
        printf(buf[0..], "    minimum resolution y = {} per millimetre\r\n", .{app.?.mode.absolute_min_y});
        printf(buf[0..], "    maximum resolution y = {} per millimetre\r\n", .{app.?.mode.absolute_max_y});
        printf(buf[0..], "    minimum resolution z = {} per millimetre\r\n", .{app.?.mode.absolute_min_z});
        printf(buf[0..], "    maximum resolution z = {} per millimetre\r\n", .{app.?.mode.absolute_max_z});

        if (app.?.mode.attributes.supports_alt_active) {
            puts("    supports alt active\r\n");
        }

        if (app.?.mode.attributes.supports_pressure_as_z) {
            puts("    supports pressure as z coordinate\r\n");
        }
    } else {
        puts("*** absolute pointer protocol is NOT supported ***\r\n");
    }

    _ = boot_services.stall(3 * 1000);

    // Check if the device supports the Graphics Output Protocol:
    if (boot_services.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&gop))) == uefi.Status.Success) {
        puts("*** graphics output protocol is supported ***\r\n");

        // `gop` is only null if no protocol support is found;
        // list the device's supported output resolutions:
        var index: u32 = 0;
        while (index < gop.?.mode.max_mode) : (index += 1) {
            var gop_info: *uefi.protocols.GraphicsOutputModeInformation = undefined;
            var info_size: usize = undefined;

            // queryMode could fail on device error or if we request an invalid mode.
            _ = gop.?.queryMode(index, &info_size, &gop_info);
            printf(buf[0..], "mode {}: {}x{}\r\n", .{ index, gop_info.horizontal_resolution, gop_info.vertical_resolution });
        }

        printf(buf[0..], "current mode is {}\r\n", .{gop.?.mode.mode});
    } else {
        puts("*** graphics output protocol is NOT supported ***\r\n");
    }

    _ = boot_services.stall(3 * 1000);

    if (boot_services.locateProtocol(&uefi.protocols.RNGProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&rng))) == uefi.Status.Success) {
        puts("*** random number generation is supported ***\r\n");

        // Test the RNG:
        // We can pick a rng, but we're going to use the default one.
        var lucky_number: u8 = undefined;
        var status = rng.?.getRNG(null, 1, @as([*]u8, @ptrCast(&lucky_number)));
        if (status == uefi.Status.Success) {
            printf(buf[0..], "    your lucky number = {}\r\n", .{lucky_number});
        } else {
            // Generating random numbers can fail.
            printf(buf[0..], "    no luck today, reason = {s}\r\n", .{@as([]const u8, switch (status) {
                uefi.Status.Unsupported => "unsupported",
                uefi.Status.DeviceError => "device error",
                uefi.Status.NotReady => "not ready",
                uefi.Status.InvalidParameter => "invalid parameter",
                else => "(unknown)",
            })});
        }
    } else {
        puts("*** random number generation is NOT supported ***\r\n");
    }

    _ = boot_services.stall(3 * 1000);

    var name_size = buffer_size;
    switch (runtime_services.getNextVariableName(&name_size, name, &guid)) {
        uefi.Status.Success => {
            printf(buf[0..], "{x:0>8}-{x:0>4}-{x:0>4}-{x:0>2}{x:0>2}{x:0>12} ", .{ guid.time_low, guid.time_mid, guid.time_high_and_version, guid.clock_seq_high_and_reserved, guid.clock_seq_low, fmt.fmtSliceHexLower(&guid.node) });
            _ = con.?.outputString(name);
            puts("\r\n");
        },
        uefi.Status.BufferTooSmall => {
            var alloc: [*:0]align(8) u16 = undefined;
            _ = boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, name_size, @as(*[*]align(8) u8, @ptrCast(&alloc)));
            for (name[0 .. buffer_size / 2], 0..) |c, i| {
                alloc[i] = c;
            }
            _ = boot_services.freePool(@as([*]align(8) u8, @ptrCast(name)));
            name = alloc;
            buffer_size = name_size;
        },
        uefi.Status.NotFound => {
            puts("???\r\n");
        },
        else => {
            puts("???\r\n");
        },
    }

    _ = boot_services.freePool(@as([*]align(8) u8, @ptrCast(name)));

    // TODO read some variables

    _ = boot_services.stall(10 * 1000);

    // Get the GOP framebuffer:
    framebuffer = @as([*]u8, @ptrFromInt(gop.?.mode.frame_buffer_base));

    // Get the current memory map:
    while (uefi.Status.BufferTooSmall == boot_services.getMemoryMap(&mmap_size, mmap, &mmap_key, &descriptor_size, &descriptor_version)) {
        if (uefi.Status.Success != boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap_size, @as(*[*]align(8) u8, @ptrCast(&mmap)))) {
            return;
        }
    }

    // Pass the current image's handle and the memory map key to exitBootServices
    // to gain full control over the hardware.
    //
    // exitBootServices may fail. If exitBootServices failed, only getMemoryMap and
    // exitBootservices may be called afterwards. The application may not return
    // anymore after the first call to exitBootServices, even if it was unsuccessful.
    //
    // Most protocols may not be used any more (except for runtime protocols
    // which nobody seems to implement).
    //
    // After exiting boot services, the following fields in the system table should
    // be set to null: ConsoleInHandle, ConIn, ConsoleOutHandle, ConOut,
    // StandardErrorHandle, StdErr, and BootServicesTable. Because the fields are
    // being modified, the table's CRC32 must be recomputed.
    //
    // All events of type event_signal_exit_boot_services will be signaled.
    //
    // Runtime services may be used. However, some restrictions apply. See the
    // UEFI specification for more information.
    //if (uefi.Status.Success == boot_services.exitBootServices(uefi.handle, mmap_key)) {
    //    // We may still use the frame buffer!
    //
    //    // draw some colors
    //    var i: u32 = 0;
    //    while (i < 640 * 480 * 4) : (i += 4) {
    //        framebuffer[i] = @as(u8, @truncate(@divTrunc(i, 256)));
    //        framebuffer[i + 1] = @as(u8, @truncate(@divTrunc(i, 1536)));
    //        framebuffer[i + 2] = @as(u8, @truncate(@divTrunc(i, 2560)));
    //    }
    //}

    printf(framebuffer[0..100], "We have reached the end!", .{});

    while (true) {}
}
