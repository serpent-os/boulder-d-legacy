/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Go buildy buildy
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.build_package;

import mason.build.util : executeCommand;
import std.path : buildPath;
import std.sumtype : match;
import std.string : format;

public import boulder.stages : Stage, StageReturn, StageContext;

/**
 * Encapsulate build stage
 */
public static immutable(Stage) stageBuildPackage = Stage("build-package", &buildPackage);

/**
 * Go do the build!
 */
static private StageReturn buildPackage(scope StageContext context)
{
    string[string] environ;
    environ["PATH"] = "/usr/bin:/usr/sbin";
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
        format!"%s=%s"(context.job.hostPaths.recipe, context.job.guestPaths.recipe),
        /* Enable colours */
        "-s", "TERM=xterm-256color",
        /* Fakeroot, end of options */
        "--fakeroot", "--",
        /* Real command to run */
        "mason", "build", "-o", context.job.guestPaths.artefacts,
        context.job.guestPaths.recipe.buildPath(context.job.name)
    ];
    auto result = executeCommand(context.containerBinary, args, environ, "/");
    auto ret = result.match!((int err) => err != 0 ? StageReturn.Failure
            : StageReturn.Success, (e) => StageReturn.Failure);
    return ret;
}
