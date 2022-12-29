/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.cmake;
 *
 * cmake files
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.cmake;

import std.path : dirName, baseName;
import std.string : endsWith;
import std.algorithm : canFind;
public import moss.deps.analysis;

/**
 * Does this look like a valid cmake provider?
 */
public AnalysisReturn acceptCmakeFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto filename = fileInfo.path;
    auto directory = filename.dirName;

    if (!directory.canFind("/cmake"))
    {
        return AnalysisReturn.NextHandler;
    }

    if ((!filename.endsWith("Config.cmake")
            && !filename.endsWith("-config.cmake")) || filename.endsWith("-Config.cmake"))
    {
        return AnalysisReturn.NextHandler;
    }

    return AnalysisReturn.NextFunction;
}

/**
 * Do something with the cmake file, for now we only
 * add providers.
 */
public AnalysisReturn handleCmakeFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto extension = fileInfo.fullPath.endsWith("-config.cmake") ? 13 : 12;

    auto providerName = fileInfo.path.baseName()[0 .. $ - extension];
    auto prov = Provider(providerName, ProviderType.CmakeName);
    analyser.bucket(fileInfo).addProvider(prov);
    return AnalysisReturn.NextHandler;
}
