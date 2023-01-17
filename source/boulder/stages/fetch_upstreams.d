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
import moss.format.source.upstream_definition;
import std.format : format;
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
    auto uc = context.upstreamCache;

    foreach (u; upstreams)
    {
        /**
         * For Git upstreams, check if it contains the requested ref. If yes, we
         * can skip the download.
         *
         * Note that `moss-fetcher` will run
         * `git fetch` to fetch new commits if it detects that the
         * upstream has been previously cloned, so we don't need to fetch new
         * commits here by ourselves if the requested ref doesn't exist and
         * can simply leave that to `moss-fetcher`.
         */
        if (u.type == UpstreamType.Git)
        {
            string refID = (() @trusted => u.git.refID)();
            if (uc.refExists(u, refID))
            {
                uc.resetToRef(u, refID);
                continue;
            }
        }
        /**
         * For plain upstreams, no point downloading it again if it's already
         * there
         */
        else if (uc.contains(u))
        {
            info(format!"Skipped download: %s"(u.uri));
            continue;
        }
        auto spath = context.upstreamCache.stagingPath(u);
        auto fetch = Fetchable(u.uri, spath, 0, u.type == UpstreamType.Plain
                ? FetchType.RegularFile : FetchType.GitRepository, null);
        context.fetcher.enqueue(fetch);
    }

    /* Run all fetches */
    while (!context.fetcher.empty)
    {
        context.fetcher.fetch();
    }
    return StageReturn.Success;
}
