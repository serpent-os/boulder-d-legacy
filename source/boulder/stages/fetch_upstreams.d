/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Fetch upstreams
 *
 * Obtain all unfetched upstreams
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.fetch_upstreams;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.algorithm : each;

/**
 * Grab all sources for build
 */
public static immutable(Stage) stageFetchUpstreams = Stage("fetch-upstreams", (StageContext context) {
    return StageReturn.Failure;
});

static private StageReturn fetchUpstreams(StageContext context)
{
    context.upstreamCache.constructDirs();
    return StageReturn.Failure;
}
