/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.build_package
 *
 * Implements the build stage
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.build_package;

import mason.build.util : executeCommand;
import std.array : join;
import std.conv : to;
import std.experimental.logger;
import std.file : exists;
import std.string : format;
import std.sumtype : match;

public import boulder.stages : Stage, StageReturn, StageContext;

/**
 * Encapsulate build stage
 */
public static immutable(Stage) stageBuildPackage = Stage("build-package", &buildPackage);

/**
 * Proxy the build to the correct helper
 */
static private StageReturn buildPackage(scope StageContext context)
{
    if (context.confinement)
    {
        return buildPackageConfined(context);
    }
    return buildPackageUnconfined(context);
}

/**
 * Perform a confined build of the package
 */
static private StageReturn buildPackageConfined(scope StageContext context)
{
    import core.sys.posix.pwd : getpwnam, passwd;

    string[string] environ;
    environ["PATH"] = "/usr/bin:/usr/sbin";
    string[] archCommand = null;
    /* Set the non-native architecture */
    if (context.architecture != "native")
    {
        archCommand = ["-a", context.architecture,];
    }
    string[] args = [
        /* Root moss filesystem */
        "--directory", context.job.hostPaths.rootfs, "--bind-rw",
        /* Output tree */
        format!"%s=%s"(context.job.hostPaths.artefacts,
                context.job.guestPaths.artefacts), "--bind-rw",
        /* Build root (with sources) */
        format!"%s=%s"(context.job.hostPaths.buildRoot,
                context.job.guestPaths.buildRoot),
        /* ccache */
        "--bind-rw",
        format!"%s=%s"(context.job.hostPaths.compilerCache,
                context.job.guestPaths.compilerCache),
        /* recipe tree */
        "--bind-ro",
        format!"%s=%s"(context.job.hostPaths.recipe,
                context.job.guestPaths.recipe),
        /* Enable colours */
        "-s", "TERM=xterm-256color",
        /* Set HOME for the packages that need it */
        "-s", format!"HOME=\"%s\""(context.job.guestPaths.buildRoot),
        /* Fakeroot, end of options */
        "--fakeroot", "--",
        /* Real command to run */
        "mason", "build",
        /* Set output directory */
        "-o", context.job.guestPaths.artefacts,
        /* Set build directory */
        "-b", context.job.guestPaths.buildRoot,
        join([context.job.guestPaths.recipe, context.job.name], "/")
    ];
    if (context.job.recipe.options.networking)
    {
        args = ["-n"] ~ args;
    }
    /* '-d' was supplied to the boulder invocation, carry it on to mason */
    if (globalLogLevel == LogLevel.trace)
    {
        args ~= "-d";
    }
    if (archCommand !is null)
    {
        args ~= archCommand;
    }
    /* pass through compiler cache request */
    if (context.compilerCache)
    {
        args ~= "--compiler-cache";
    }
    trace(format!"%s: executeCommand(%s, %s, %s, \"/\")"(__FUNCTION__,
            context.containerBinary, args, environ));
    auto result = executeCommand(context.containerBinary, args, environ, "/");
    auto ret = result.match!((int err) => err != 0 ? StageReturn.Failure
            : StageReturn.Success, (e) => StageReturn.Failure);
    return ret;
}

/**
 * Handle unconfined builds
 */
static private StageReturn buildPackageUnconfined(scope StageContext context)
{
    string[string] environ = ["PATH": "/usr/bin:/usr/sbin"];
    /* runuser */
    string[] args = [
        /* Only run as nobody. No permisions *at all* kthxbai */
        "-u", "nobody", "--",
        /* fakeroot pls! */
        "fakeroot", "--",
        /* Build with mason */
        "mason", "build", "-o", context.job.hostPaths.artefacts, "-b",
        context.job.hostPaths.buildRoot, "-a", context.architecture,
        /* Here be your recipe. */
        join([context.job.unconfinedRecipe, context.job.name], "/")
    ];
    /* '-d' was supplied to the boulder invocation, carry it on to mason */
    if (globalLogLevel == LogLevel.trace)
    {
        args ~= "-d";
    }
    trace(format!"%s: executeCommand('runuser, %s, %s, \"/\"')"(__FUNCTION__, args, environ));
    auto result = executeCommand("runuser", args, environ, "/");
    auto ret = result.match!((int err) => err != 0 ? StageReturn.Failure
            : StageReturn.Success, (e) => StageReturn.Failure);
    return ret;
}
