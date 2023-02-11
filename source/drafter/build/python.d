/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * drafer.build.python
 *
 * Python integration
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module drafter.build.python;
import moss.deps.analysis;
import drafter : Drafter;
import drafter.build : BuildType, Build;
import std.path : baseName;

/**
 * Discover python projects
 */
static private AnalysisReturn acceptPython(scope Analyser an, ref FileInfo inpath)
{
    Drafter c = an.userdata!Drafter;
    auto bn = inpath.path.baseName;
    import std.string : count;

    switch (bn)
    {
    case "pyproject.toml":
    case "setup.cfg":
        c.incrementBuildConfidence(BuildType.PythonPEP517, 100);
        return AnalysisReturn.IncludeFile;
    case "setup.py":
        c.incrementBuildConfidence(BuildType.PythonSetuptools, 100);
        return AnalysisReturn.IncludeFile;
    default:
        return AnalysisReturn.NextHandler;
    }
}

/**
 * Handler for python projects
 */
public static AnalysisChain pythonChain = AnalysisChain("python", [
    &acceptPython
], 20);

/**
 * Python PEP517 Build (pyproject.toml/setup.cfg)
 */
public final class Pythonpep517Build : Build
{
override:

    string setup()
    {
        return null;
    }

    string build()
    {
        return "%pyproject_build";
    }

    string install()
    {
        return "%pyproject_install";
    }

    string check()
    {
        return null;
    }
}

/**
 * Python Setuptools Build (setup.py)
 */
public final class PythonsetuptoolsBuild : Build
{
override:

    string setup()
    {
        return null;
    }

    string build()
    {
        return "%python_build";
    }

    string install()
    {
        return "%python_install";
    }

    string check()
    {
        return null;
    }
}
