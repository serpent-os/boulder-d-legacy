/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.create_root
 *
 * Simple stage that will just create required build directories
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.create_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.algorithm : each;
import std.format : format;
import std.file : mkdirRecurse;
import core.sys.posix.unistd : chown;
import moss.core.mounts;
import std.string : toStringz;
import std.experimental.logger;

/**
 * Handle creation of root tree
 */
public static immutable(Stage) stageCreateRoot = Stage("create-root", (StageContext context) {
    auto guestPkgCachePath = context.job.joinPath(context.job.guestPaths.pkgCache);
    auto paths = [
        context.job.hostPaths.artefacts, context.job.hostPaths.buildRoot,
        context.job.hostPaths.compilerCache, context.job.hostPaths.pkgCache,
    ];

    import core.sys.posix.pwd : getpwnam, passwd;

    passwd* p = getpwnam("nobody");
    immutable nobodyUser = p is null ? 65_534 : p.pw_uid;

    /* Not sharing a cache */
    if (context.confinement)
    {
        paths ~= guestPkgCachePath;
    }
    else
    {
        paths ~= context.job.unconfinedRecipe;
    }

    paths.each!((p) {
        p.mkdirRecurse();
        chown(p.toStringz, nobodyUser, nobodyUser);
    });

    /* Confinement requires bind-mounted package cache .. */
    if (context.confinement)
    {
        // auto pkgCache = Mount.bindRW(context.job.hostPaths.pkgCache, guestPkgCachePath);
        // auto err = pkgCache.mount();
        // if (!err.isNull)
        // {
        //     error(format!"Failed to mount %s: %s"(pkgCache.target, err.get.toString));
        //     return StageReturn.Failure;
        // }
        // context.addMount(pkgCache);
    }
    else
    {
        auto recipeMount = FileMount.bindRO(context.job.hostPaths.recipe, context.job.unconfinedRecipe);
        recipeMount.mount();
        context.addMount(recipeMount);
    }

    return StageReturn.Success;
});
