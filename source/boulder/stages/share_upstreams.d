/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Share upstreams
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.share_upstreams;

public import boulder.stages : Stage, StageReturn, StageContext;
import moss.format.source.upstream_definition;
import std.path : buildPath, baseName;
import std.algorithm : filter;

/**
 * Make sources available
 */
public static immutable(Stage) stageShareUpstreams = Stage("share-upstreams", &shareUpstreams);

/**
 * Handle the actual sharing of upstreams
 */
static private StageReturn shareUpstreams(scope StageContext context)
{
    auto plains = context.job.recipe.upstreams.values.filter!((u) => u.type == UpstreamType.Plain);
    foreach (p; plains)
    {
        auto name = p.plain.rename !is null ? p.plain.rename : p.uri.baseName;
        auto tgt = context.job.hostPaths.buildRoot.buildPath(name);
        context.upstreamCache.share(p, tgt);
    }
    return StageReturn.Success;
}
