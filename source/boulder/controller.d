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

import moss.core.platform : platform;
import moss.format.source;
import std.algorithm : each;
import std.file : mkdirRecurse;
import std.path : buildPath, dirName, baseName, absolutePath;
import std.process;
import std.stdio : File, writeln;
import std.string : format;

import boulder.buildjob;

immutable static private auto SharedRootBase = "/var/cache/boulder";

enum RecipeStage
{
    None = 0,
    Resolve,
    FetchSources,
    ConstructRoot,
    RunBuild,
    Failed,
    Complete,
}

/**
 * Encapsulate some basic directory properties
 */
private struct Container
{
    /** Installation root for the container */
    string root;

    /** Build directory (where we .. build.) */
    string build;

    /** Target build tree */
    static immutable(string) targetBuild = "/mason/build";

    /** Ccache directory (global shared) */
    static immutable(string) ccache = SharedRootBase.buildPath("ccache");

    /** Recipe directory (bind-ro) */
    string input;

    /**
     * The input directory in the container
     */
    static immutable(string) targetInput = "/mason/input";

    /** Output directory (bind-rw) */
    string output;

    /**
     * The output directory in the container
     */
    static immutable(string) targetOutput = "/mason/output";

    this(scope Spec* spec)
    {
        auto p = platform();

        /* Reusable path component */
        auto subpath = format!"%s-%s-%d-%s"(spec.source.name,
                spec.source.versionIdentifier, spec.source.release, p.name);

        root = SharedRootBase.buildPath("root", subpath);
        build = SharedRootBase.buildPath("build", subpath);
        output = SharedRootBase.buildPath("output", subpath);

        import core.sys.posix.sys.stat;
        import std.conv : octal;
        import std.string : toStringz;
        import std.exception : enforce;

        [root, build, ccache, output].each!((d) => d.mkdirRecurse());

        auto ret = chmod(output.toStringz,
                S_IRUSR | S_IWUSR | S_IWOTH | S_IROTH | S_IWGRP | S_IRGRP
                | S_IXUSR | S_IXOTH | S_IXGRP);
        enforce(ret == 0);
    }
}

/**
 * This is the main entry point for all build commands which will be dispatched
 * to mason in the chroot environment via moss-container.
 */
public final class Controller
{
    this()
    {
    }

    /**
     * Begin the build process for a specific recipe
     */
    void build(in string filename)
    {
        auto fi = File(filename, "r");
        recipe = new Spec(fi);
        recipe.parse();

        auto job = new BuildJob(recipe, filename);
        writeln(job.guestPaths);
        writeln(job.hostPaths);
        scope (exit)
        {
            fi.close();
        }
    }

    Spec* recipe = null;
}
