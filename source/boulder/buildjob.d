/* SPDX-License-Identifier: Zlib */

/**
 * Build Job
 *
 * Simple Build Job encapsulation
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

import moss.format.source.spec;
import std.path : buildPath, dirName, absolutePath, buildNormalizedPath;
import std.string : format;

immutable static private auto SharedRootBase = "/var/cache/boulder";

package struct BuildPaths
{
    /**
     * Location for binary artefacts
     */
    string artefacts;

    /**
     * Location for the recipe tree
     */
    string recipe;

    /**
     * Location for the compiler cache
     */
    string compilerCache;

    /**
     * Location for the build tree
     */
    string buildRoot;
}

/**
 * Encapsulation of a BuildJob - including vital paths
 */
public final class BuildJob
{
    /**
     * Construct a new BuildJob from a parsed SpecFile
     */
    this(Spec* specFile, in string path)
    {
        _recipe = specFile;

        auto subpath = format!"%s-%s-%s"(_recipe.source.name,
                _recipe.source.versionIdentifier, _recipe.source.release);
        /* Output */
        _hostPaths.artefacts = SharedRootBase.buildPath("artefacts", subpath);
        /* Where to build */
        _hostPaths.buildRoot = SharedRootBase.buildPath("build", subpath);
        /* Where to cache */
        _hostPaths.compilerCache = SharedRootBase.buildPath("ccache");
        /* Where is the recipe..? */
        _hostPaths.recipe = path.dirName.absolutePath.buildNormalizedPath;
    }

    /**
     * Our build recipe
     *
     * Returns: The Spec pointer
     */
    pure @property const(Spec*) recipe() @safe @nogc nothrow const
    {
        return _recipe;
    }

    /**
     * Guest paths
     *
     * Returns: Immutable reference to guest paths
     */
    @property ref immutable(BuildPaths) guestPaths() @safe @nogc nothrow const
    {
        static BuildPaths p = BuildPaths("/mason/artefacts", "/mason/recipe",
                "/mason/ccache", "/mason/build",);

        return cast(immutable(BuildPaths)) p;
    }

    /**
     * Host paths
     *
     * Returns: Immutable reference to host paths
     */
    pure @property ref immutable(BuildPaths) hostPaths() @safe @nogc nothrow const
    {
        return cast(immutable(BuildPaths)) _hostPaths;
    }

private:

    Spec* _recipe;
    BuildPaths _hostPaths;
}
