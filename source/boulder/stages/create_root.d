/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Clean root
 *
 * Simple stage that will just create required directories
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.create_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.algorithm : each;
import std.file : mkdirRecurse;

/**
 * Handle creation of root tree
 */
public static immutable(Stage) stageCreateRoot = Stage("create-root", (StageContext context) {
    auto paths = [
        context.job.hostPaths.artefacts, context.job.hostPaths.buildRoot
    ];
    paths.each!((p) => p.mkdirRecurse());
    return StageReturn.Success;
});
