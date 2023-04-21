/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages.chroot_package
 *
 * Implements chrooting into a package recipe build environment
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages.chroot_package;

import mason.build.util : executeCommand;
import std.experimental.logger;
import std.string : format;
import std.sumtype : match;

public import boulder.stages : Stage, StageReturn, StageContext;

/**
 * Encapsulate chroot stage
 */
public static immutable(Stage) stageChrootPackage = Stage("chroot-package", &chrootPackage);

/**
 * Chroot into a package's build location
 *
 * Params:
 *      context = context for the stage
 * Returns: a fleshed out moss-container command to chroot into a build location
 */
static public StageReturn chrootPackage(scope StageContext context)
{
    import core.sys.posix.pwd : getpwnam, passwd;

    passwd* p = getpwnam("nobody");
    immutable nobodyUser = p is null ? 65_534 : p.pw_uid;

    string[string] environ;
    environ["PATH"] = "/usr/bin:/usr/sbin";
    string[] archCommand;
    /* Set the non-native architecture */
    if (context.architecture != "native")
    {
        archCommand = ["-a", context.architecture,];
    }
    string[] args = [
        /* Root moss filesystem */
        "--directory", context.job.hostPaths.rootfs, "--bind-rw",
        /* Output tree */
        format!"%s=%s"(context.job.hostPaths.artefacts,
                context.job.guestPaths.artefacts), "--bind-rw",
        /* Build root (with sources) */
        format!"%s=%s"(context.job.hostPaths.buildRoot,
                context.job.guestPaths.buildRoot),
        /* ccache */
        "--bind-rw",
        format!"%s=%s"(context.job.hostPaths.compilerCache,
                context.job.guestPaths.compilerCache),
        /* recipe tree */
        "--bind-ro",
        format!"%s=%s"(context.job.hostPaths.recipe, context.job.guestPaths.recipe),
        /* Start at working directory */
        "--workdir", context.job.guestPaths.buildRoot,
        /* Set the user to use */
        format!"--uid=%s"(nobodyUser),
        /* Enable colours */
        "-s", "TERM=xterm-256color",
        /* Set HOME for the packages that need it */
        "-s", format!"HOME=\"%s\""(context.job.guestPaths.buildRoot),
        /* Set $USER (note: currently no /etc/passwd or /etc/shadow in the chroot) */
        "-s", "USER=nobody",
    ];
    if (context.job.recipe.options.networking)
    {
        args = ["-n"] ~ args;
    }
    if (archCommand !is null)
    {
        args ~= archCommand;
    }
    trace(format!"%s: executeCommand(%s, %s, %s, \"/\")"(__FUNCTION__,
            context.containerBinary, args, environ));
    immutable result = executeCommand(context.containerBinary, args, environ, "/");
    auto ret = result.match!((int err) => err != 0 ? StageReturn.Failure
            : StageReturn.Success, (e) => StageReturn.Failure);
    return ret;
}
