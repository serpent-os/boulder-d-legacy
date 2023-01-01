/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.binary;
 *
 * Simplistic binary() providers, i.e. path in /usr/bin
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.binary;

import std.string : startsWith;
public import moss.deps.analysis;

/**
 * Detect files in /usr/bin
 *
 * Params:
 *      analyser = Scoped analyser for this run
 *      fileInfo = Current file to run analysis on
 * Returns: AnalysisReturn.NextFunction always
 */
public AnalysisReturn handleBinaryFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto filename = fileInfo.path;

    if (filename.startsWith("/usr/bin/"))
    {
        auto prov = Provider(fileInfo.path[`/usr/bin/`.length .. $], ProviderType.BinaryName);
        analyser.bucket(fileInfo).addProvider(prov);
    }
    else if (filename.startsWith("/usr/sbin"))
    {
        auto prov = Provider(fileInfo.path[`/usr/sbin/`.length .. $], ProviderType.SystemBinaryName);
        analyser.bucket(fileInfo).addProvider(prov);
    }

    /* Let someone else toy with it now */
    return AnalysisReturn.NextHandler;
}
