/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.clean_root
 *
 * A simplisti stage that removes the existing build root
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
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
        context.job.hostPaths.artefacts, context.job.hostPaths.buildRoot,
        context.job.hostPaths.rootfs
    ];
    auto existing = paths.filter!((p) => p.exists);
    if (existing.empty)
    {
        return StageReturn.Skipped;
    }
    existing.each!((p) => p.rmdirRecurse);
    return StageReturn.Success;
});
