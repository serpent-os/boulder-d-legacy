/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.deletecache_command
 *
 * Implements the `boulder delete-cache` subcommand
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.cmddeletecache;

import core.atomic : atomicOp;
import std.array : array;
import std.experimental.logger;
import std.file :
    DirEntry,
    FileException,
    attrIsDir,
    attrIsFile,
    dirEntries,
    exists,
    getSize,
    remove,
    rmdir,
    SpanMode;
import std.format : format;
import std.parallelism : parallel;

import boulder.buildjob;
import boulder.upstreamcache;
import dopt;
import moss.core.sizing;

/**
 * The DeleteCacheCommand is responsible deleting the various caches used by boulder
 */
@Command() /*@Alias("dc")*/
@Help("Delete assets & caches stored by boulder")
public struct DeleteCache
{
    /** Delete all assets & caches */
    @Option() @Short("a") @Long("all") @Help("Delete all assets and caches used by boulder")
    bool deleteAll = false;

    /** Delete artefacts */
    @Option() @Short("A") @Long("artefacts") @Help("Delete artefacts cache")
    bool delArtefacts = false;

    /** Delete build */
    @Option() @Short("b") @Long("build") @Help("Delete build cache")
    bool delBuild = false;

    /** Delete ccache */
    @Option() @Short("c") @Long("ccache") @Help("Delete ccache cache")
    bool delCcache = false;

    /** Delete pkgCache */
    @Option() @Short("P") @Long("pkgCache") @Help("Delete pkgCache cache")
    bool delPkgCache = false;

    /** Delete upstreams */
    @Option() @Short("u") @Long("upstreams") @Help("Delete upstreams cache")
    bool delUpstreams = false;

    /** Get total disk usage of boulder assets and caches */
    @Option() @Short("s") @Long("show-sizes") @Help("Display disk usage used by boulder assets and caches and exit.")
    bool showSizes = false;

    void run()
    {
        if (showSizes)
        {
            /* Print out disk usage and return if showSizes is requested */
            this.runShowSize();
        }
        else {
            this.runDeleteCache();
        }
    }

private:

    void runShowSize()
    {
        string[] cachePaths = [
            sharedRootArtefactsCache(),
            sharedRootBuildCache(),
            sharedRootCcacheCache(),
            sharedRootPkgCacheCache(),
            sharedRootRootCache(),
            sharedRootUpstreamsCache(),
        ];
        double totalSize = 0;
        foreach (string path; cachePaths)
        {
            try
            {
                auto size = getSizeDir(path);
                totalSize += size;
                info(format!"Size of %s is %s"(path, formattedSize(size)));
            }
            catch (FileException e)
            {
                warning(format!"Failed to compute size of file: %s"(e.msg));
            }
        }
        info(format!"Total size: %s"(formattedSize(totalSize)));
    }

    void runDeleteCache()
    {
        /* Figure out what paths we're nuking */
        string[] nukeCachePaths = [sharedRootRootCache()];
        if (deleteAll)
        {
            delArtefacts = true;
            delBuild = true;
            delCcache = true;
            delPkgCache = true;
            delUpstreams = true;
        }
        if (delArtefacts)
        {
            nukeCachePaths ~= sharedRootArtefactsCache();
        }
        if (delBuild)
        {
            nukeCachePaths ~= sharedRootBuildCache();
        }
        if (delCcache)
        {
            nukeCachePaths ~= sharedRootCcacheCache();
        }
        if (delPkgCache)
        {
            nukeCachePaths ~= sharedRootPkgCacheCache();
        }
        if (delUpstreams)
        {
            nukeCachePaths ~= sharedRootUpstreamsCache();
        }

        double totalSize = 0;
        foreach (string path; nukeCachePaths)
        {
            auto size = getSizeDir(path);
            try
            {
                deleteDir(path);
                info(format!"Removed: %s, %s"(path, formattedSize(size)));
                totalSize += size;
            }
            catch (FileException e)
            {
                warning(format!"Failed to delete all files in %s: %s"(path, e.msg));
            }
        }
        info(format!"Total restored size: %s"(formattedSize(totalSize)));
    }
}

/**
 * Deletes all files in a directory in parallel, this is quicker than rmdirRecurse.
 * Params:
 *      path = directory to remove
 */
private void deleteDir(in string path) @trusted
{
    DirEntry[] dirs;
    DirEntry[] files;
    foreach (name; dirEntries(path, SpanMode.depth, false))
    {
        if (!attrIsDir(name.linkAttributes))
        {
            files ~= name;
        }
        else
        {
            dirs ~= name;
        }
    }
    foreach (file; parallel(files))
    {
        remove(file);
    }
    /* Dirs are already sorted depth first :) */
    foreach (dir; dirs)
    {
        rmdir(dir);
    }
}

/**
 * Get the disk usage of a directory
 * Params:
 *      path = directory to get size of
 * Returns: totalSize
 */
private double getSizeDir(in string path) @trusted
{
    /* Use a global var and increment it with an atomicOp to
       ensure an consistent result due to parallel stat */
    shared ulong totalSize;
    foreach (name; parallel(dirEntries(path, SpanMode.breadth, false)))
    {
        if (attrIsFile(name.linkAttributes))
        {
            atomicOp!"+="(totalSize, getSize(name));
        }
    }
    /* Return a thread local var */
    immutable double returnSize = totalSize;
    return returnSize;
}
