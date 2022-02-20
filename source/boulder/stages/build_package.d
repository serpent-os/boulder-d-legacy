/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Go buildy buildy
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.build_package;

import mason.build.util : executeCommand;
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
        "--directory", context.job.hostPaths.rootfs, "--bind-rw",
        format!"%s=%s"(context.job.hostPaths.artefacts,
                context.job.guestPaths.artefacts), "--bind-rw",
        format!"%s=%s"(context.job.hostPaths.buildRoot,
                context.job.guestPaths.buildRoot),
        /*"--bind-rw", format!"%s=%s"(context.job.hostPaths.compilerCache, context.job.guestPaths.compilerCache),*/
        "--bind-ro",
        format!"%s=%s"(context.job.hostPaths.recipe, context.job.guestPaths.recipe),
        "-s", "TERM=xterm-256color", "--fakeroot", "--", "bash", "--login",
    ];
    auto result = executeCommand(context.containerBinary, args, environ, "/");
    auto ret = result.match!((int err) => err != 0 ? StageReturn.Failure
            : StageReturn.Success, (e) => StageReturn.Failure);
    return ret;
}
