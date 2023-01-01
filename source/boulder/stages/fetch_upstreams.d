/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.fetch_upstreams
 *
 * Obtain all unfetched upstreams
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.fetch_upstreams;

public import boulder.stages : Stage, StageReturn, StageContext;

import moss.fetcher;
import std.algorithm : each;
import std.experimental.logger;

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
            infof("Skipped download: %s", u.uri);
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
