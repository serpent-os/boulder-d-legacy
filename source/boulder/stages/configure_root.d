/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.configure_root
 *
 * Configure the root prior to populating it
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.configure_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.path : dirName;
import std.file : mkdirRecurse, write;
import mason.build.util : executeCommand, ExecutionError;
import std.sumtype : match;
import std.array : join;

/**
 * Go ahead and configure the tree
 *
 * TODO: Don't lock this to protosnek! Use a configuration
 */
public static immutable(Stage) stageConfigureRoot = Stage("configure-root", (StageContext context) {
    /* Root configuration requires confinement */
    if (!context.confinement)
    {
        return StageReturn.Skipped;
    }

    string[string] env;
    env["PATH"] = "/usr/bin";
    auto result = executeCommand(context.mossBinary, [
        "-y", "ar", "-D", context.job.hostPaths.rootfs, "protosnek",
        "https://dev.serpentos.com/protosnek/x86_64/stone.index",
    ], env);
    return result.match!((i) => i == 0 ? StageReturn.Success
        : StageReturn.Failure, (ExecutionError e) => StageReturn.Failure);
});
