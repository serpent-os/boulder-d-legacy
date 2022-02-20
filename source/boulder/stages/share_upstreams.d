/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Share upstreams
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.share_upstreams;

public import boulder.stages : Stage, StageReturn, StageContext;

/**
 * Make sources available
 */
public static immutable(Stage) stageShareUpstreams = Stage("share-upstreams", &shareUpstreams);

/**
 * Handle the actual sharing of upstreams
 */
static private StageReturn shareUpstreams(scope StageContext context)
{
    return StageReturn.Failure;
}
