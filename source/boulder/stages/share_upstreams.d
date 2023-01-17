/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.share_upstreams
 *
 * This stage makes the fetched sources available in the build environment
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.share_upstreams;

public import boulder.stages : Stage, StageReturn, StageContext;
import moss.format.source.upstream_definition;
import std.path : baseName, dirName;
import std.file : mkdirRecurse;
import std.algorithm : filter;
import std.array : join;

/**
 * Make sources available
 */
public static immutable(Stage) stageShareUpstreams = Stage("share-upstreams", &shareUpstreams);

/**
 * Handle the actual sharing of upstreams
 */
static private StageReturn shareUpstreams(scope StageContext context)
{
    auto shareable = context.job.recipe.upstreams.values.filter!(
            (u) => u.type == UpstreamType.Plain || u.type == UpstreamType.Git);
    foreach (p; shareable)
    {
        auto name = (p.type == UpstreamType.Plain && p.plain.rename !is null) ? p.plain.rename
            : p.uri.baseName;
        auto tgt = join([context.job.hostPaths.buildRoot, "sourcedir", name], "/");
        auto dd = tgt.dirName;
        dd.mkdirRecurse();
        context.upstreamCache.share(p, tgt);
    }
    return StageReturn.Success;
}
