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
import moss.fetcher;
import std.stdio : stderr;

/**
 * Grab all sources for build
 */
public static immutable(Stage) stageFetchUpstreams = Stage("fetch-upstreams", &fetchUpstreams);

/**
 * Handle the actual fetching of upstreams
 */
static private StageReturn fetchUpstreams(scope StageContext context)
{
    context.upstreamCache.constructDirs();
    auto upstreams = context.job.recipe.upstreams.values;
    foreach (u; upstreams)
    {
        /* No point downloading it again.. */
        if (context.upstreamCache.contains(u))
        {
            stderr.writeln("[boulder] Skipping download of " ~ u.uri);
            continue;
        }
        auto spath = context.upstreamCache.stagingPath(u);
        auto fetch = Fetchable(u.uri, spath, 0, FetchType.RegularFile, null);
        context.fetcher.enqueue(fetch);
    }
    /* Run all fetches */
    while (!context.fetcher.empty)
    {
        context.fetcher.fetch();
    }
    return StageReturn.Success;
}
