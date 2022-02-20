/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2022 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.controller;

import boulder.buildjob;
import moss.fetcher;
import moss.format.source;
import std.algorithm : filter;
import std.exception : enforce;
import std.file : exists, rmdirRecurse;
import std.path : buildNormalizedPath, dirName;
import std.stdio : File, stderr, writeln, writefln;
import boulder.stages;

/**
 * This is the main entry point for all build commands which will be dispatched
 * to mason in the chroot environment via moss-container.
 */
public final class Controller : StageContext
{
    this()
    {
        /* Construct recipe stages here */

        /* Figure out where our utils are */
        debug
        {
            import std.file : thisExePath;

            pragma(msg,
                    "\n\n!!!!!!!!!!\n\nUSING UNSAFE DEBUG BUILD PATHS. DO NOT USE IN PRODUCTION\n\n");
            _mossBinary = thisExePath.dirName.buildNormalizedPath("../../moss/build/moss");
            _containerBinary = thisExePath.dirName.buildNormalizedPath(
                    "../../moss-container/build/moss-container");
        }
        else
        {
            _mossBinary = "/usr/bin/moss";
            _containerBinary = "/usr/bin/moss-container";
        }

        enforce(_mossBinary.exists, "not found: " ~ _mossBinary);
        enforce(_containerBinary.exists, "not found: " ~ _containerBinary);

        writeln("moss: ", _mossBinary);
        writeln("moss-container: ", _containerBinary);
        _upstreamCache = new UpstreamCache();
        _fetcher = new FetchController();
    }

    /**
     * Return our job
     */
    pure override @property const(BuildJob) job() @safe @nogc nothrow const
    {
        return _job;
    }

    /**
     * Return moss path
     */
    pure override @property immutable(string) mossBinary() @safe @nogc nothrow const
    {
        return _mossBinary;
    }

    /**
     * Return container path
     */
    pure override @property immutable(string) containerBinary() @safe @nogc nothrow const
    {
        return _containerBinary;
    }

    pure override @property UpstreamCache upstreamCache() @safe @nogc nothrow
    {
        return _upstreamCache;
    }

    /**
     * Returns: The FetchContext
     */
    pure override @property FetchController fetcher() @safe @nogc nothrow
    {
        return _fetcher;
    }

    /**
     * Begin the build process for a specific recipe
     */
    void build(in string filename)
    {
        auto fi = File(filename, "r");
        recipe = new Spec(fi);
        recipe.parse();

        _job = new BuildJob(recipe, filename);
        writeln(_job.guestPaths);
        writeln(_job.hostPaths);
        scope (exit)
        {
            fi.close();
        }

        int stageIndex = 0;
        int nStages = cast(int) boulderStages.length;

        build_loop: while (true)
        {
            /* Dun dun dun */
            if (stageIndex > nStages - 1)
            {
                break build_loop;
            }

            auto stage = boulderStages[stageIndex];
            enforce(stage.functor !is null);

            writeln("[boulder] ", stage.name);
            StageReturn result = StageReturn.Failure;
            try
            {
                result = stage.functor(this);
            }
            catch (Exception e)
            {
                stderr.writefln!"Exception: %s"(e.message);
                result = StageReturn.Failure;
            }

            final switch (result)
            {
            case StageReturn.Failure:
                writeln("[boulder] Failed ", stage.name);
                break build_loop;
            case StageReturn.Success:
                writeln("[boulder] Success ", stage.name);
                ++stageIndex;
                break;
            case StageReturn.Skipped:
                writeln("[boulder] Skipped ", stage.name);
                ++stageIndex;
                break;
            }
        }
    }

private:

    string _mossBinary;
    string _containerBinary;

    Spec* recipe = null;
    BuildJob _job;
    UpstreamCache _upstreamCache = null;
    FetchController _fetcher = null;
}
