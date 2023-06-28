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

import std.experimental.logger;
import std.format : format;

import boulder.buildjob : sharedRootArtefactsCache, sharedRootBuildCache,
    sharedRootCcacheCache, sharedRootPkgCacheCache, sharedRootRootCache;
import boulder.upstreamcache : sharedRootUpstreamsCache;
import dopt;
import moss.core : ExitStatus;
import moss.core.sizing : formattedSize;

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
    @Option() @Short("s") @Long("sizes") @Help("Display disk usage used by boulder assets and caches.")
    bool sizes = false;

    /**
     * Boulder assets and caches deletion
     * Params:
     *      argv = arguments passed to the cli
     * Returns: ExitStatus.Success on success, ExitStatus.Failure on failure
     */
    int run(ref string[] argv)
    {
        immutable useDebug = this.findAncestor!BoulderCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;

        if (argv.length > 0)
        {
            warning(
                    "Unexcepted number of arguments specified. For help, run boulder delete-cache -h");
            return ExitStatus.Failure;
        }

        /* Print out disk usage and return if sizes is requested */
        if (sizes == true)
        {
            string[] cachePaths = [
                sharedRootArtefactsCache(), sharedRootBuildCache(),
                sharedRootCcacheCache(), sharedRootPkgCacheCache(),
                sharedRootRootCache(), sharedRootUpstreamsCache(),
            ];
            double totalSize = 0;
            foreach (string path; cachePaths)
            {
                auto size = getSizeDir(path);
                totalSize += size;
                info(format!"Size of %s is %s"(path, formattedSize(size)));
            }
            info(format!"Total size: %s"(formattedSize(totalSize)));
            return ExitStatus.Success;
        }

        /* Figure out what paths we're nuking */
        string[] nukeCachePaths = [sharedRootRootCache()];
        if (deleteAll == true)
        {
            delArtefacts = true;
            delBuild = true;
            delCcache = true;
            delPkgCache = true;
            delUpstreams = true;
        }
        if (delArtefacts == true)
            nukeCachePaths ~= sharedRootArtefactsCache();
        if (delBuild == true)
            nukeCachePaths ~= sharedRootBuildCache();
        if (delCcache == true)
            nukeCachePaths ~= sharedRootCcacheCache();
        if (delPkgCache == true)
            nukeCachePaths ~= sharedRootPkgCacheCache();
        if (delUpstreams == true)
            nukeCachePaths ~= sharedRootUpstreamsCache();

        /* Nuke the paths */
        double totalSize = 0;
        auto exitStatus = ExitStatus.Success;
        foreach (string path; nukeCachePaths)
        {
            auto size = getSizeDir(path);
            exitStatus = deleteDir(path);
            if (exitStatus == ExitStatus.Failure)
            {
                warning(format!"Failed to delete all files in %s"(path));
            }
            info(format!"Removed: %s, %s"(path, formattedSize(size)));
            totalSize += size;
        }
        info(format!"Total restored size: %s"(formattedSize(totalSize)));

        return exitStatus;
    }
}

/**
 * Deletes all files in a directory in parallel, this is quicker than rmdirRecurse.
 * Params:
 *      path = directory to remove
 * Returns: ExitStatus.Success, ExitStatus.Failure
 */
auto deleteDir(in string path) @trusted
{
    import std.file : attrIsDir, DirEntry, dirEntries, exists, FileException,
        remove, rmdir, SpanMode;
    import std.parallelism : parallel;

    /* Whether we failed to remove some files */
    bool failed;

    DirEntry[] dirs;
    DirEntry[] files;

    try
    {
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
    catch (FileException e)
    {
        warning(format!"Issue deleting %s, reason: %s"(path, e));
        failed = true;
    }
    if (failed == true)
    {
        return ExitStatus.Failure;
    }
    return ExitStatus.Success;
}

/**
 * Get the disk usage of a directory
 * Params:
 *      path = directory to get size of
 * Returns: totalSize
 */
auto getSizeDir(in string path) @trusted
{
    import core.atomic : atomicOp;
    import std.array : array;
    import std.file : attrIsFile, dirEntries, FileException, getSize, SpanMode;
    import std.parallelism : parallel;

    /* Use a global var and increment it with an atomicOp to
       ensure an consistent result due to parallel stat */
    shared ulong totalSize;

    try
    {
        foreach (name; parallel(dirEntries(path, SpanMode.breadth, false).array))
        {
            if (attrIsFile(name.linkAttributes))
            {
                atomicOp!"+="(totalSize, getSize(name));
            }
        }
    }
    /* Don't crash and burn if we fail to stat a file */
    catch (FileException e)
    {
        trace(format!"Caught a FileException within %s, reason: %s"(path, e));
    }

    /* Return a thread local var */
    immutable double returnSize = totalSize;

    return returnSize;
}
