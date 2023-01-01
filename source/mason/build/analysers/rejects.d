/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.rejects;
 *
 * Straight up unwanted.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.rejects;

import std.algorithm : canFind;
import std.experimental.logger;
import std.path : dirName;
import std.string : startsWith, endsWith, format;
public import moss.deps.analysis;

/*
 * Reject any "bad" path from inclusion
 */
public AnalysisReturn dropBadPaths(scope Analyser analyser, ref FileInfo info)
{
    /* non-/usr = bad */
    if (!info.path.startsWith("/usr/"))
    {
        if (!info.path.startsWith("/usr"))
        {
            warning(format!"Not including non /usr/ file: %s"(info.path));
        }
        return AnalysisReturn.IgnoreFile;
    }

    /* libtool files break the world  */
    if (info.path.endsWith(".la") && info.path.dirName.canFind("usr/lib"))
    {
        trace(format!"[Analyse] Rejecting libtool file: %s"(info.path));
        return AnalysisReturn.IgnoreFile;
    }

    return AnalysisReturn.NextHandler;
}
