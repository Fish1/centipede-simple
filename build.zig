const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = .Wayland,
    });
    const raylib_module = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const flecs_dep = b.dependency("zflecs", .{});
    const flecs_module = flecs_dep.module("root");
    const flecs_artifact = flecs_dep.artifact("flecs");

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.linkLibrary(raylib_artifact);
    root_module.linkLibrary(flecs_artifact);
    root_module.addImport("raylib", raylib_module);
    root_module.addImport("flecs", flecs_module);

    const exe = b.addExecutable(.{
        .name = "centipede",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
