/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.buildjob
 *
 * Provides encapsulation of a recipe build job
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.buildjob;

import moss.format.source.spec;
import std.path : baseName, dirName, absolutePath, buildNormalizedPath;
import std.string : format, startsWith;
import std.array : join;

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

    /**
     * Where to save moss downloads
     */
    string pkgCache;

    /**
     * Where is the rootfs?
     */
    string rootfs;
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
        _name = path.baseName;

        auto subpath = format!"%s-%s-%s"(_recipe.source.name,
                _recipe.source.versionIdentifier, _recipe.source.release);
        /* Output */
        _hostPaths.artefacts = join([SharedRootBase, "artefacts", subpath], "/");
        /* Where to build */
        _hostPaths.buildRoot = join([SharedRootBase, "build", subpath], "/");
        /* Where to cache */
        _hostPaths.compilerCache = join([SharedRootBase, "ccache"], "/");
        /* Where to save binaries */
        _hostPaths.pkgCache = join([SharedRootBase, "pkgCache"], "/");
        /* Where is the recipe..? */
        _hostPaths.recipe = path.dirName.absolutePath.buildNormalizedPath;
        /* And where is the rootfs? */
        _hostPaths.rootfs = join([SharedRootBase, "root", subpath], "/");
        /* Unconfined recipe tree? */
        _unconfinedRecipe = join([SharedRootBase, "recipe", subpath], "/");
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
     * Our filename
     *
     * Returns: Immutable string as filename
     */
    pure @property immutable(string) name() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _name;
    }

    /**
     * Cheekily employed bind mount to deviate unix permissions
     *
     * "Nobody" user can't read the recipe so bind mount it and make it
     * available.
     */
    pure @property immutable(string) unconfinedRecipe() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _unconfinedRecipe;
    }

    /**
     * Guest paths
     *
     * Returns: Immutable reference to guest paths
     */
    @property ref immutable(BuildPaths) guestPaths() @safe @nogc nothrow const
    {
        static BuildPaths p = BuildPaths("/mason/artefacts", "/mason/recipe",
                "/mason/ccache", "/mason/build", "/.moss/cache", "/");

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

    /**
     * Safely join the path onto the rootfs tree
     */
    auto joinPath(in string target) @safe nothrow const
    {
        return join([
            _hostPaths.rootfs, target.startsWith("/") ? target[1 .. $]: target
        ], "/");
    }

    /** 
     * Extra deps
     */
    @property void extraDeps(string[] deps) @safe
    {
        _extraDeps = deps;
    }

    /**
     * Automatic extra deps
     */
    @property auto extraDeps() @safe const
    {
        return _extraDeps;
    }

private:

    Spec* _recipe;
    BuildPaths _hostPaths;
    string _name = null;
    string _unconfinedRecipe;
    string[] _extraDeps;
}
