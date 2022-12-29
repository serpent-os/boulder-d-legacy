/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.binary;
 *
 * Simplistic binary() providers, i.e. path in /usr/bin
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.binary;

import std.string : startsWith;
public import moss.deps.analysis;

/**
 * Detect files in /usr/bin
 */
public AnalysisReturn acceptBinaryFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto filename = fileInfo.path;

    if (!filename.startsWith("/usr/bin/"))
    {
        return AnalysisReturn.NextHandler;
    }

    return AnalysisReturn.NextFunction;
}

/**
 * Add provider for files in /usr/bin that people can run from PATH
 */
public AnalysisReturn handleBinaryFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto providerName = fileInfo.path()[9 .. $];
    auto prov = Provider(providerName, ProviderType.BinaryName);
    analyser.bucket(fileInfo).addProvider(prov);
    return AnalysisReturn.NextHandler;
}
