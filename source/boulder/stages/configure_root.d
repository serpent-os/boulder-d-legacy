/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.configure_root
 *
 * Configure the root prior to populating it
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.configure_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.path : dirName;
import std.file : mkdirRecurse, write;
import mason.build.util : executeCommand, ExecutionError;
import std.algorithm : startsWith;
import std.sumtype : match;
import std.array : join;
import std.conv : to;
import std.experimental.logger;
import std.string : chomp, chompPrefix, format;

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

    foreach (collection; context.profile.collections)
    {

        /* Ensure the index is updated first for local collections */
        if (collection.uri.startsWith("file://"))
        {
            immutable realPath = chompPrefix(collection.uri, "file://");
            immutable profilePath = chomp(realPath, "stone.index");

            info(format!"Updating index for `%s` at `%s`"(collection.id, realPath));
            auto idxResult = executeCommand(context.mossBinary, [
                "index", profilePath
            ], env);

            bool failed;
            idxResult.match!((i) { failed = i != 0; }, (ExecutionError e) {
                error(format!"Failed to update index `%s` at `%s`. Error: %s"(collection.id,
                realPath, e.toString));
                failed = true;
            });
            if (failed)
            {
                return StageReturn.Failure;
            }
        }

        auto result = executeCommand(context.mossBinary, [
            "-y", "repo", "add", "-D", context.job.hostPaths.rootfs,
            collection.id, collection.uri, "-p", to!string(collection.priority)
        ], env);
        bool failed;
        result.match!((i) { failed = i != 0; }, (ExecutionError e) {
            error(format!"Execution error: %s"(e.toString));
            failed = true;
        });
        if (failed)
        {
            return StageReturn.Failure;
        }
    }

    return StageReturn.Success;
});
