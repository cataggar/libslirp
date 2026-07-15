const std = @import("std");

const version = std.SemanticVersion{
    .major = 4,
    .minor = 9,
    .patch = 3,
};

const sources = [_][]const u8{
    "arp_table.c",
    "bootp.c",
    "cksum.c",
    "dhcpv6.c",
    "dnssearch.c",
    "if.c",
    "ip6_icmp.c",
    "ip6_input.c",
    "ip6_output.c",
    "ip_icmp.c",
    "ip_input.c",
    "ip_output.c",
    "mbuf.c",
    "misc.c",
    "ncsi.c",
    "ndp_table.c",
    "sbuf.c",
    "slirp.c",
    "socket.c",
    "state.c",
    "stream.c",
    "tcp_input.c",
    "tcp_output.c",
    "tcp_subr.c",
    "tcp_timer.c",
    "tftp.c",
    "udp.c",
    "udp6.c",
    "util.c",
    "version.c",
    "vmstate.c",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const glib_dep = b.dependency("glib", .{
        .target = target,
        .optimize = optimize,
    });

    const write_files = b.addWriteFiles();
    const version_h = write_files.add("libslirp-version.h",
        \\/* SPDX-License-Identifier: BSD-3-Clause */
        \\#ifndef LIBSLIRP_VERSION_H_
        \\#define LIBSLIRP_VERSION_H_
        \\
        \\#ifdef __cplusplus
        \\extern "C" {
        \\#endif
        \\
        \\#define SLIRP_MAJOR_VERSION 4
        \\#define SLIRP_MINOR_VERSION 9
        \\#define SLIRP_MICRO_VERSION 3
        \\#define SLIRP_VERSION_STRING "4.9.3"
        \\
        \\#define SLIRP_CHECK_VERSION(major,minor,micro)                     \
        \\    (SLIRP_MAJOR_VERSION > (major) ||                              \
        \\     (SLIRP_MAJOR_VERSION == (major) &&                            \
        \\      SLIRP_MINOR_VERSION > (minor)) ||                            \
        \\     (SLIRP_MAJOR_VERSION == (major) &&                            \
        \\      SLIRP_MINOR_VERSION == (minor) &&                            \
        \\      SLIRP_MICRO_VERSION >= (micro)))
        \\
        \\#ifdef __cplusplus
        \\} /* extern "C" */
        \\#endif
        \\
        \\#endif /* LIBSLIRP_VERSION_H_ */
        \\
    );
    const generated_headers = write_files.getDirectory();

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(generated_headers);
    mod.addIncludePath(b.path("src"));
    mod.linkLibrary(glib_dep.artifact("glib-2.0"));
    mod.addCMacro("G_LOG_DOMAIN", "\"Slirp\"");
    mod.addCMacro("BUILDING_LIBSLIRP", "1");
    mod.addCMacro("LIBSLIRP_STATIC", "1");
    mod.addCMacro("GLIB_STATIC_COMPILATION", "1");
    mod.addCMacro("GIO_STATIC_COMPILATION", "1");
    mod.addCMacro("GMODULE_STATIC_COMPILATION", "1");
    mod.addCMacro("GI_STATIC_COMPILATION", "1");
    mod.addCMacro("GOBJECT_STATIC_COMPILATION", "1");
    mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &sources,
        .flags = &.{
            "-std=gnu99",
            "-Wno-unused-parameter",
        },
    });

    const lib = b.addLibrary(.{
        .name = "slirp",
        .linkage = .static,
        .root_module = mod,
        .version = version,
    });
    lib.installHeader(b.path("src/libslirp.h"), "slirp/libslirp.h");
    lib.installHeader(version_h, "slirp/libslirp-version.h");
    b.installArtifact(lib);

    const smoke_source = b.addWriteFiles().add("libslirp-smoke-test.c",
        \\#include <slirp/libslirp.h>
        \\#include <string.h>
        \\
        \\int main(void)
        \\{
        \\    const SlirpConfig config = {
        \\        .version = SLIRP_CONFIG_VERSION_MAX,
        \\        .in_enabled = true,
        \\    };
        \\    const SlirpCb callbacks = {0};
        \\    Slirp *slirp;
        \\
        \\    if (strcmp(slirp_version_string(), "4.9.3") != 0)
        \\        return 1;
        \\
        \\    slirp = slirp_new(&config, &callbacks, NULL);
        \\    if (slirp == NULL)
        \\        return 2;
        \\
        \\    slirp_cleanup(slirp);
        \\    return 0;
        \\}
        \\
    );
    const smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    smoke_module.addCSourceFile(.{
        .file = smoke_source,
        .flags = &.{"-std=gnu99"},
    });
    smoke_module.linkLibrary(lib);

    const smoke_test = b.addExecutable(.{
        .name = "libslirp-smoke-test",
        .root_module = smoke_module,
    });
    const run_smoke_test = b.addRunArtifact(smoke_test);
    const test_step = b.step("test", "Run the libslirp smoke test");
    test_step.dependOn(&run_smoke_test.step);
}
