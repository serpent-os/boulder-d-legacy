/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Clean root
 *
 * Simple stage that will just create required directories
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.create_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.algorithm : each;
import std.file : mkdirRecurse;
import core.sys.posix.unistd : chown;
import moss.core.mounts;
import std.string : toStringz;
import std.stdio : writefln;

import boulder.stages : nobodyUser;

/**
 * Handle creation of root tree
 */
public static immutable(Stage) stageCreateRoot = Stage("create-root", (StageContext context) {
    auto guestPkgCachePath = context.job.joinPath(context.job.guestPaths.pkgCache);
    auto paths = [
        context.job.hostPaths.artefacts, context.job.hostPaths.buildRoot,
        context.job.hostPaths.compilerCache, context.job.hostPaths.pkgCache,
    ];

    /* Not sharing a cache */
    if (context.confinement)
    {
        paths ~= guestPkgCachePath;
    }

    paths.each!((p) => {
        p.mkdirRecurse();
        chown(p.toStringz, nobodyUser, nobodyUser);
    }());

    /* Confinement requires bind-mounted package cache .. */
    if (context.confinement)
    {
        auto pkgCache = Mount.bindRW(context.job.hostPaths.pkgCache, guestPkgCachePath);
        auto err = pkgCache.mount();
        if (!err.isNull)
        {
            writefln("[boulder] Failed to mount %s: %s", pkgCache.target, err.get.toString);
            return StageReturn.Failure;
        }
        context.addMount(pkgCache);
    }

    return StageReturn.Success;
});
