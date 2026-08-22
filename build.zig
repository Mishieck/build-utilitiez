const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const ResolvedTarget = Build.ResolvedTarget;
const Step = Build.Step;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run tests");

    const mod = addModule(
        b,
        target,
        "build_utilitiez",
        "src/root.zig",
        test_step,
        &.{},
        true,
    );

    _ = addExecutable(
        b,
        target,
        optimize,
        "build_utilitiez",
        "src/main.zig",
        test_step,
        &.{
            .{ "build_utilitiez", mod },
        },
        true,
    );

    addExample(
        b,
        target,
        optimize,
        "example",
        "",
        &.{.{ "build_utilitiez", mod }},
    );
}

fn addModule(
    b: *Build,
    target: ResolvedTarget,
    comptime name: []const u8,
    comptime path: []const u8,
    test_step: *Build.Step,
    modules: []const ModuleEntry,
    comptime is_root: bool,
) *Build.Module {
    const module = b.addModule(name, .{
        .root_source_file = b.path(path),
        .target = target,
    });

    for (modules) |mod| module.addImport(mod.@"0", mod.@"1");

    const test_name = comptime if (is_root) "root" else name;
    const local_test_step = b.step("test_" ++ test_name, "Run tests");
    const module_tests = b.addTest(.{ .root_module = module });
    const run_module_tests = b.addRunArtifact(module_tests);
    for (modules) |mod| module_tests.root_module.addImport(mod.@"0", mod.@"1");
    test_step.dependOn(&run_module_tests.step);
    local_test_step.dependOn(&run_module_tests.step);

    return module;
}

fn addExecutable(
    b: *Build,
    target: ResolvedTarget,
    optimize: OptimizeMode,
    comptime name: []const u8,
    comptime path: []const u8,
    test_step: *Step,
    modules: []const ModuleEntry,
    comptime is_main: bool,
) *Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        }),
    });

    for (modules) |mod| exe.root_module.addImport(mod.@"0", mod.@"1");

    b.installArtifact(exe);
    const run_name = if (is_main) "run" else name;
    const run_step = b.step(run_name, "Run " ++ name ++ ".");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const test_name = comptime if (is_main) "exe" else name;
    const local_test_step = b.step("test_" ++ test_name, "Run tests");
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    for (modules) |mod| exe_tests.root_module.addImport(mod.@"0", mod.@"1");
    test_step.dependOn(&run_exe_tests.step);
    local_test_step.dependOn(&run_exe_tests.step);

    return exe;
}

const ModuleEntry = struct { []const u8, *Build.Module };

fn addExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    comptime name: []const u8,
    comptime dir: []const u8,
    modules: []const ModuleEntry,
) void {
    const example_dir = comptime if (dir.len > 0) dir else "examples";
    const separator = comptime [_]u8{fs.path.sep};
    const path = comptime example_dir ++ separator ++ name ++ ".zig";

    const examples_exe = b.addExecutable(.{
        .name = "example_" ++ name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        }),
    });

    for (modules) |module| examples_exe.root_module.addImport(module.@"0", module.@"1");
    b.installArtifact(examples_exe);

    const run_step = b.step("example_" ++ name, "Run the " ++ name ++ " example.");

    const run_cmd = b.addRunArtifact(examples_exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
