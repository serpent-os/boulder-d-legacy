/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.chroot_command
 *
 * Helper to chroot into a recipe build location with container
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.cmdchroot;

import std.experimental.logger;
import std.range : empty;

import boulder.controller;
import dopt;

/**
 * The ChrootCommand is responsible for handling requests to chroot into
 * a stone.yml's build location
 */
@Command() /*@Alias("cr")*/
@Help("Chroot into a recipe's build location using the container application.")
public struct Chroot
{
    @Positional() @Help("Recipe path")
    string recipePath;

    void run(string resourcePath, string profile)
    {
        /* TODO use a (custom) prefix to look for `container`. */

        if (this.recipePath.empty())
        {
            trace("No recipe specified, considering stone.yml recipe in current directory");
            this.recipePath = "stone.yml";
        }

        /* Dummy vars to create a controller */
        immutable outputDirectory = ".";
        immutable unconfined = false;
        immutable compilerCache = false;
        immutable architecture = "native";

        auto controller = new Controller(
            outputDirectory,
            architecture,
            !unconfined,
            profile,
            compilerCache,
            resourcePath,
        );
        controller.chroot(recipePath);
    }
}
