const targets = [_]std.Target.Query{
    // zig fmt: off
    .{ .cpu_arch = .x86_64,  .os_tag = .windows },
    .{ .cpu_arch = .x86,     .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },

    .{ .cpu_arch = .x86_64,  .os_tag = .linux   },
    .{ .cpu_arch = .x86,     .os_tag = .linux   },
    .{ .cpu_arch = .aarch64, .os_tag = .linux   },
    .{ .cpu_arch = .arm,     .os_tag = .linux   },

    .{ .cpu_arch = .x86_64,  .os_tag = .macos   },
    .{ .cpu_arch = .aarch64, .os_tag = .macos   },

    .{ .cpu_arch = .x86_64,  .os_tag = .freebsd },
    .{ .cpu_arch = .arm,     .os_tag = .freebsd },
    .{ .cpu_arch = .aarch64, .os_tag = .freebsd },

    .{ .cpu_arch = .x86_64,  .os_tag = .openbsd },
    .{ .cpu_arch = .arm,     .os_tag = .openbsd },
    .{ .cpu_arch = .aarch64, .os_tag = .openbsd },

    .{ .cpu_arch = .x86_64,  .os_tag = .netbsd  },
    .{ .cpu_arch = .arm,     .os_tag = .netbsd  },
    .{ .cpu_arch = .aarch64, .os_tag = .netbsd  },
    // zig fmt: on
};

pub fn build(b: *Build) !void {
    const native = b.resolveTargetQuery(.{});
    const optimize = b.standardOptimizeOption(.{});

    const deps: Deps = .{
        .lua = b.dependency("lua", .{}),
        .lfs = b.dependency("luafilesystem", .{}),
        .luasystem = b.dependency("luasystem", .{}),
        .inspect = b.dependency("inspect", .{}),
        .argparse = b.dependency("argparse", .{}),
        .lexical_path = b.dependency("lexical_path", .{}),
        .tl = b.dependency("tl", .{}),
    };

    const lua_interpreter = buildLuaInterpreter(b, deps, native);

    const compile_aggregate_tl = try runLua(b, lua_interpreter, deps);
    const aggregate_lua = a: {
        compile_aggregate_tl.addFileArg(deps.tl.path("tl"));
        compile_aggregate_tl.addArgs(&.{ "gen", "--no-check", "aggregate.tl" });
        break :a compile_aggregate_tl.addPrefixedOutputFileArg("-o", "aggregate.lua");
    };

    const agg_step = try runLua(b, lua_interpreter, deps);
    agg_step.addFileArg(aggregate_lua);
    agg_step.addArg("../build/");
    inline for (.{
        deps.lexical_path,
        deps.inspect,
        deps.argparse,
        deps.luasystem,
        deps.tl,
    }) |dep|
        agg_step.addDirectoryArg(dep.path(""));
    const aggregate_c = agg_step.addPrefixedOutputFileArg("--target-path=", "aggregate.c");
    b.step("aggregate", "Build the aggregated C file").dependOn(&agg_step.step);

    const all = b.step("all", "Build the bundle for each (preset) target");

    var has_native = false;
    for (targets) |query| {
        const install, const actual_target = addTarget(
            b,
            optimize,
            query,
            deps,
            aggregate_c,
        );
        const step = b.step(
            b.fmt("{t}-{t}", .{ actual_target.cpu.arch, actual_target.os.tag }),
            b.fmt("Build the bundle for {t} {t}", .{ actual_target.cpu.arch, actual_target.os.tag }),
        );
        if (actual_target.os.tag == builtin.target.os.tag and
            actual_target.cpu.arch == builtin.target.cpu.arch)
        {
            has_native = true;
            b.default_step = step;
        }
        step.dependOn(install);
        all.dependOn(install);
    }

    if (!has_native) {
        const install, const actual_target = addTarget(
            b,
            optimize,
            .{},
            deps,
            aggregate_c,
        );
        b.default_step = b.step(
            b.fmt("{t}-{t}", .{ actual_target.cpu.arch, actual_target.os.tag }),
            b.fmt("Build the bundle for the native target ({t} {t})", .{ actual_target.cpu.arch, actual_target.os.tag }),
        );
        b.default_step.dependOn(install);
    }
}

const Deps = struct {
    lua: *Build.Dependency,
    lfs: *Build.Dependency,
    luasystem: *Build.Dependency,
    inspect: *Build.Dependency,
    argparse: *Build.Dependency,
    lexical_path: *Build.Dependency,
    tl: *Build.Dependency,
};

fn buildLuaInterpreter(b: *Build, deps: Deps, native: Build.ResolvedTarget) *Build.Step.Compile {
    const mod = b.addModule("lua", .{
        .target = native,
        .optimize = .ReleaseSafe,
    });
    mod.link_libc = true;
    // bit of hack, but luai_openlibs is invoked as a statement
    // so we put declarations and such here
    mod.addCMacro(
        "luai_openlibs(L)",
        "do {" ++
            "int luaopen_lfs(lua_State *);" ++
            "int luaopen_system_core(lua_State *);" ++
            "luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);" ++
            "lua_pushcfunction(L, luaopen_lfs),lua_setfield(L, -2, \"lfs\");" ++
            "lua_pushcfunction(L, luaopen_system_core),lua_setfield(L, -2, \"system.core\");" ++
            "lua_pop(L, 1);" ++
            "luaL_openselectedlibs(L, ~0, 0);" ++
            "} while(0)",
    );
    mod.addCSourceFile(.{ .file = deps.lua.path("src/lua.c") });
    addLuaSources(mod, deps.lua);
    addLuaSystemSources(mod, deps.luasystem, native.result.os.tag == .windows);
    addLuaFileSystemSources(mod, deps.lfs);
    const result = b.addExecutable(.{
        .name = "lua",
        .root_module = mod,
    });
    b.step("lua-interpreter", "Build (and install) the lua interpreter")
        .dependOn(&b.addInstallArtifact(result, .{}).step);
    return result;
}

fn runLua(b: *Build, lua: *Build.Step.Compile, deps: Deps) !*Build.Step.Run {
    const static = struct {
        var LUA_PATH: ?[]const u8 = null;
    };
    if (static.LUA_PATH == null) {
        var arena_instance: std.heap.ArenaAllocator = .init(b.allocator);
        defer arena_instance.deinit();
        const arena = arena_instance.allocator();

        var builder: std.ArrayList(u8) = try .initCapacity(arena, 1024);

        inline for (.{
            .{ deps.luasystem, "" },
            .{ deps.inspect, "" },
            .{ deps.lexical_path, "build" },
            .{ deps.argparse, "src" },
            .{ deps.tl, "" },
        }) |pair| {
            const dep, const sub_path = pair;
            const str_path = try (try dep.path(sub_path).getPath4(b, null)).toString(arena);

            try builder.appendSlice(arena, str_path);
            try builder.appendSlice(arena, "/?.lua;");
            try builder.appendSlice(arena, str_path);
            try builder.appendSlice(arena, "/?/init.lua;");
        }

        try builder.appendSlice(arena, "../build/?.lua;../build/?/init.lua");

        static.LUA_PATH = try b.graph.arena.dupe(u8, builder.items);
    }

    const run = b.addRunArtifact(lua);
    run.setEnvironmentVariable("LUA_PATH", static.LUA_PATH.?);
    return run;
}

fn addTarget(
    b: *Build,
    optimize: std.builtin.OptimizeMode,
    query: std.Target.Query,
    deps: Deps,
    agg: Build.LazyPath,
) struct { *Build.Step, std.Target } {
    const target = b.resolveTargetQuery(query);
    const name = b.fmt("cyan-{t}-{t}", .{
        target.result.cpu.arch,
        target.result.os.tag,
    });

    const mod = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
    });
    mod.link_libc = true;

    mod.addCSourceFile(.{ .file = agg });
    addLuaSources(mod, deps.lua);
    addLuaSystemSources(mod, deps.luasystem, target.result.os.tag == .windows);
    addLuaFileSystemSources(mod, deps.lfs);

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });
    exe.step.name = name;
    return .{ &b.addInstallArtifact(exe, .{}).step, target.result };
}

fn addLuaSources(mod: *Build.Module, lua: *Build.Dependency) void {
    mod.addIncludePath(lua.path("src"));
    mod.addCSourceFile(.{ .file = lua.path("src/lapi.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/linit.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lstrlib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lauxlib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/liolib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ltable.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lbaselib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/llex.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ltablib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lcode.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lmathlib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ltm.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lcorolib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lmem.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lctype.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/loadlib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ldblib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lobject.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ldebug.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lopcodes.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lutf8lib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ldo.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/loslib.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lvm.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/ldump.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lparser.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lzio.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lfunc.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lstate.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lundump.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lgc.c") });
    mod.addCSourceFile(.{ .file = lua.path("src/lstring.c") });
}

fn addLuaSystemSources(mod: *Build.Module, luasystem: *Build.Dependency, is_windows: bool) void {
    if (is_windows) {
        mod.linkSystemLibrary("winmm", .{});
        mod.linkSystemLibrary("bcrypt", .{});
    }
    mod.addIncludePath(luasystem.path("src"));
    mod.addCSourceFile(.{ .file = luasystem.path("src/bitflags.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/compat.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/core.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/environment.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/random.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/term.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/time.c") });
    mod.addCSourceFile(.{ .file = luasystem.path("src/wcwidth.c") });
}

fn addLuaFileSystemSources(mod: *Build.Module, lfs: *Build.Dependency) void {
    mod.addIncludePath(lfs.path("src"));
    mod.addCSourceFile(.{ .file = lfs.path("src/lfs.c") });
}

const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
