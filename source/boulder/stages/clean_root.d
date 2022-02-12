/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Clean root
 *
 * Simple stage that will just clean the existing root if found
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.clean_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.algorithm : each, filter;
import std.file : rmdirRecurse, exists;

/**
 * Handle cleaning of root tree
 */
public static immutable(Stage) stageCleanRoot = Stage("clean-root", (StageContext context) {
    auto paths = [
        context.job.hostPaths.artefacts, context.job.hostPaths.buildRoot
    ];
    auto existing = paths.filter!((p) => p.exists);
    if (existing.empty)
    {
        return StageReturn.Skipped;
    }
    existing.each!((p) => p.rmdirRecurse);
    return StageReturn.Success;
});
