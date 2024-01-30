const std = @import("std");

const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const version_info = b.addExecutable(.{
        .name = "generate_version_info",
        .root_source_file = .{ .path = "generate_version_info.zig" },
        .target = target,
    });

    const verinfo_step = b.addRunArtifact(version_info);
    const gen_output = verinfo_step.addOutputFileArg("version_info.zig");
    verinfo_step.addArg("0");
    verinfo_step.addArg("0");
    verinfo_step.addArg("1");
    verinfo_step.addArg("true");

    const concat = b.addExecutable(.{
        .name = "generate_concat",
        .root_source_file = .{ .path = "generate_concat.zig" },
        .target = target,
    });

    const gen_concat_step = b.addRunArtifact(concat);
    const concat_output = gen_concat_step.addOutputFileArg("concat.zig");

    const exe = b.addExecutable(.{
        .name = "bootx64",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "index.zig" },
        .target = CrossTarget{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.uefi,
            .abi = Target.Abi.msvc,
        },
        .optimize = optimize,
    });

    exe.addAnonymousModule("version_info", .{
        .source_file = gen_output,
    });

    exe.addAnonymousModule("concat", .{
        .source_file = concat_output,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-no-reboot",
        "-no-shutdown",

        "-m",
        "128M",

        "-drive",
        "if=pflash,format=raw,readonly=on,file=./arch/x64/code.fd",

        "-drive",
        "if=pflash,format=raw,readonly=on,file=./arch/x64/vars.fd",

        "-drive",
        "format=raw,file=fat:rw:esp",

        "-kernel",
        "esp/efi/boot/bootx64.efi",

        "-debugcon",
        "stdio",
        "-d",
        "int",

        "-d",
        "cpu_reset",
    });

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
