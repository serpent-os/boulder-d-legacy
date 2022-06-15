/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - Autotools integration
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.build.autotools;

import std.regex;
import moss.deps.analysis;
import drafter : Drafter;
import drafter.build : BuildType;
import std.path : baseName;
import std.algorithm : canFind;
import std.mmfile;

/**
 * Ugly as all living fuck but lets us discover pkgconfig dependencies
 * in configure.ac files using group index 2.
 */
static immutable reConfigurePkgconfig = ctRegex!(
        r"PKG_CHECK_MODULES\s?\(\s?\[([A-Za-z_]+)\s?\]\s?,\s?\[\s?(\s?[A-Za-z0-9\-_+]+)\s?]");

/**
 * Is this autotools?
 */
static public AnalysisReturn acceptAutotools(scope Analyser an, ref FileInfo inpath)
{
    Drafter dr = an.userdata!Drafter;
    auto bn = inpath.path.baseName;
    import std.string : count;

    /**
     * Depth too great
     */
    if (inpath.path.count("/") > 1)
    {
        return AnalysisReturn.NextHandler;
    }

    switch (bn)
    {
    case "configure.ac":
    case "configure":
    case "Makefile.am":
    case "Makefile":
        dr.incrementBuildConfidence(BuildType.Autotools, 10);
        return AnalysisReturn.IncludeFile;
    default:
        return AnalysisReturn.NextHandler;
    }
}

/**
 * Handler for autotools files
 */
public static AnalysisChain autotoolsChain = AnalysisChain("autotools", [
        &acceptAutotools
        ], 10);

public struct AutotoolsBuild
{
    string setup()
    {
        return "%configure";
    }

    string build()
    {
        return "%make";
    }

    string install()
    {
        return "%make_install";
    }

    string check()
    {
        return null;
    }
}
