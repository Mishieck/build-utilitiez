const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const ResolvedTarget = Build.ResolvedTarget;
const Step = Build.Step;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run tests.");

    const mod = addModule(.{
        .build = b,
        .target = target,
        .name = "build_utilitiez",
        .path = "src/root.zig",
        .test_step = test_step,
        .imports = &.{},
        .is_root = true,
    });

    _ = addExecutable(.{
        .build = b,
        .target = target,
        .optimize = optimize,
        .name = "build_utilitiez",
        .path = "src/main.zig",
        .test_step = test_step,
        .imports = &.{
            .{ "build_utilitiez", mod },
        },
        .is_main = true,
    });

    addExample(.{
        .build = b,
        .target = target,
        .optimize = optimize,
        .name = "example",
        .dir = "",
        .test_step = test_step,
        .imports = &.{.{ "build_utilitiez", mod }},
    });
}

pub fn addModule(module: Module) *Build.Module {
    const mod = module.build.addModule(module.name, .{
        .root_source_file = module.build.path(module.path),
        .target = module.target,
    });

    for (module.imports) |i| mod.addImport(i.@"0", i.@"1");

    const test_name = if (module.is_root) "root" else module.name;
    var buffer: [1024]u8 = undefined;
    const test_step_name = fmt.bufPrint(&buffer, "test_{s}", .{test_name}) catch unreachable;
    const local_test_step = module.build.step(test_step_name, "Run module tests.");
    const module_tests = module.build.addTest(.{ .root_module = mod });
    const run_module_tests = module.build.addRunArtifact(module_tests);
    for (module.imports) |i| module_tests.root_module.addImport(i.@"0", i.@"1");
    module.test_step.dependOn(&run_module_tests.step);
    local_test_step.dependOn(&run_module_tests.step);

    return mod;
}

pub const Module = struct {
    build: *Build,
    target: ResolvedTarget,
    name: []const u8,
    /// Relative path of the module.
    path: []const u8,
    /// Top-level test step. All the module test steps will depend on this.
    test_step: *Build.Step,
    imports: []const ModuleEntry,
    /// Indicates if the module is thee root module of the package.
    is_root: bool,
};

pub fn addExecutable(executable: Executable) *Build.Step.Compile {
    const name = executable.name;
    const exe = executable.build.addExecutable(.{
        .name = name,
        .root_module = executable.build.createModule(.{
            .root_source_file = executable.build.path(executable.path),
            .target = executable.target,
            .optimize = executable.optimize,
        }),
    });

    for (executable.imports) |i| exe.root_module.addImport(i.@"0", i.@"1");

    executable.build.installArtifact(exe);
    const run_name = if (executable.is_main) "run" else name;
    var run_step_message_buffer: [1024]u8 = undefined;
    const run_step_message = fmt.bufPrint(&run_step_message_buffer, "Run {s}.", .{name}) catch unreachable;
    const run_step = executable.build.step(run_name, run_step_message);
    const run_cmd = executable.build.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(executable.build.getInstallStep());

    if (executable.build.args) |args| run_cmd.addArgs(args);

    const test_name = if (executable.is_main) "exe" else name;
    var test_step_name_buffer: [1024]u8 = undefined;
    const test_step_name = fmt.bufPrint(&test_step_name_buffer, "test_{s}", .{test_name}) catch unreachable;
    const local_test_step = executable.build.step(test_step_name, "Run executable tests.");
    const exe_tests = executable.build.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = executable.build.addRunArtifact(exe_tests);
    for (executable.imports) |mod| exe_tests.root_module.addImport(mod.@"0", mod.@"1");
    executable.test_step.dependOn(&run_exe_tests.step);
    local_test_step.dependOn(&run_exe_tests.step);

    return exe;
}

pub const Executable = struct {
    build: *Build,
    target: ResolvedTarget,
    optimize: OptimizeMode,
    name: []const u8,
    /// Relative path of the executable.
    path: []const u8,
    /// Top-level test step. All the module test steps will depend on this.
    test_step: *Build.Step,
    imports: []const ModuleEntry,
    /// Indicates if the executable is the main executable of the package.
    is_main: bool,
};

const ModuleEntry = struct { []const u8, *Build.Module };

pub fn addExample(example: Example) void {
    const example_dir = if (example.dir.len > 0) example.dir else "examples";
    const separator = [_]u8{fs.path.sep};
    var path_buffer: [1024]u8 = undefined;
    const path = fmt.bufPrint(&path_buffer, "{s}{s}{s}.zig", .{ example_dir, separator, example.name }) catch unreachable;

    const name = example.name;
    var executable_name_buffer: [1024]u8 = undefined;
    const executable_name = fmt.bufPrint(&executable_name_buffer, "example_{s}", .{name}) catch unreachable;
    const exe = example.build.addExecutable(.{
        .name = executable_name,
        .root_module = example.build.createModule(.{
            .root_source_file = example.build.path(path),
            .target = example.target,
            .optimize = example.optimize,
        }),
    });

    for (example.imports) |i| exe.root_module.addImport(i.@"0", i.@"1");
    example.build.installArtifact(exe);

    var run_step_name_buffer: [1024]u8 = undefined;
    const run_step_name = fmt.bufPrint(&run_step_name_buffer, "example_{s}", .{name}) catch unreachable;
    var run_step_message_buffer: [1024]u8 = undefined;
    const run_step_message = fmt.bufPrint(&run_step_message_buffer, "Run the {s} example.", .{name}) catch unreachable;
    const run_step = example.build.step(run_step_name, run_step_message);
    const run_cmd = example.build.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(example.build.getInstallStep());
    if (example.build.args) |args| run_cmd.addArgs(args);

    var test_step_name_buffer: [1024]u8 = undefined;
    const test_step_name = fmt.bufPrint(&test_step_name_buffer, "test_example_{s}", .{name}) catch unreachable;
    const local_test_step = example.build.step(test_step_name, "Run example tests.");
    const exe_tests = example.build.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = example.build.addRunArtifact(exe_tests);
    for (example.imports) |mod| exe_tests.root_module.addImport(mod.@"0", mod.@"1");
    example.test_step.dependOn(&run_exe_tests.step);
    local_test_step.dependOn(&run_exe_tests.step);
}

pub const Example = struct {
    build: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    /// The directory in which the example is.
    dir: []const u8,
    /// Top-level test step. All the module test steps will depend on this.
    test_step: *Build.Step,
    imports: []const ModuleEntry,
};
