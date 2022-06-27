/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.sync_artefacts
 *
 * Clone the build artefacts into the work tree (outside container)
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.sync_artefacts;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.array : array;
import std.algorithm : filter, map;
import std.file : dirEntries, SpanMode, exists;
import std.path : baseName;
import std.string : join, format;
import std.sumtype : match;
import std.experimental.logger;
import moss.core.ioutil;

/**
 * Make sources available
 */
public static immutable(Stage) stageSyncArtefacts = Stage("sync-artefacts", &syncArtefacts);

/**
 * Make the build results available in the output directorys
 */
static private StageReturn syncArtefacts(scope StageContext context)
{
    import std.file : remove;

    immutable artefactDir = context.job.hostPaths.artefacts;
    auto items = dirEntries(artefactDir, SpanMode.shallow, false).array
        .filter!((a) => a.isFile)
        .map!((a) => a.name);
    immutable outputDir = context.outputDirectory;

    foreach (copyable; items)
    {
        immutable toPath = [outputDir, copyable.baseName].join("/");
        if (toPath.exists)
        {
            toPath.remove();
        }
        auto res = IOUtil.hardlinkOrCopy(copyable, toPath);
        auto ret = res.match!((CError err) {
            error(format!"Error syncing asset %s: %s"(copyable, err.toString));
            return false;
        }, (b) => true);
        if (!ret)
        {
            return StageReturn.Failure;
        }
    }
    return StageReturn.Success;
}
