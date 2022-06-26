/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Drafter - Autotools integration
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module drafter.build.meson;
import std.regex;
import moss.deps.analysis;
import drafter : Drafter;
import drafter.build : BuildType;
import std.path : baseName;
import std.algorithm : canFind;
import std.mmfile;

/**
 * Used for dependency matching ignoring the version specifier
 */
static immutable reMesonDependency = ctRegex!r"dependency\s?\(\s?'\s?([A-Za-z0-9+-_]+)";

/**
 * Handle the find_program() call to map to binary() providers
 */
static immutable reMesonProgram = ctRegex!r"find_program\s?\(\s?'\s?([A-Za-z0-9+-_]+)";

/**
 * Discover meson projects
 */
static private AnalysisReturn acceptMeson(scope Analyser an, ref FileInfo inpath)
{
    Drafter dr = an.userdata!Drafter;
    auto bn = inpath.path.baseName;
    import std.string : count;

    switch (bn)
    {
    case "meson.build":
        /**
            * Depth too great
            */
        if (inpath.path.count("/") > 1)
        {
            return AnalysisReturn.NextHandler;
        }
        dr.incrementBuildConfidence(BuildType.Meson, 100);
        return AnalysisReturn.NextFunction;
    case "meson_options.txt":
        dr.incrementBuildConfidence(BuildType.Meson, 100);
        return AnalysisReturn.IncludeFile;
    default:
        return AnalysisReturn.NextHandler;
    }
}

/**
 * Scan a meson.build file
 */
static private AnalysisReturn scanMeson(scope Analyser an, ref FileInfo inpath)
{
    scope auto mmap = new MmFile(inpath.fullPath);
    auto data = cast(ubyte[]) mmap[0 .. $];
    auto rawData = cast(string) data;

    /* Check all meson dependency() calls */
    foreach (m; rawData.matchAll(reMesonDependency))
    {
        auto dependencyTarget = m[1];
        auto de = Dependency(dependencyTarget.dup, DependencyType.PkgconfigName);
        an.bucket(inpath).addDependency(de);
    }

    /* Check all meson find_program() calls */
    foreach (m; rawData.matchAll(reMesonProgram))
    {
        auto programTarget = m[1];
        /* Relative programs are a no go */
        if (programTarget.canFind('/'))
        {
            continue;
        }
        auto de = Dependency(programTarget.dup, DependencyType.BinaryName);
        an.bucket(inpath).addDependency(de);
    }

    return AnalysisReturn.IncludeFile;
}

/**
 * Handler for meson files
 */
public static AnalysisChain mesonChain = AnalysisChain("meson", [
        &acceptMeson, &scanMeson
        ], 20);

/**
 * Build instructions
 */
public struct MesonBuild
{
    string setup()
    {
        return "%meson";
    }

    string build()
    {
        return "%meson_build";
    }

    string install()
    {
        return "%meson_install";
    }

    string check()
    {
        return null;
    }
}
