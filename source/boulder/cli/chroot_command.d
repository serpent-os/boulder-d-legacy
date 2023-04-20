/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.chroot_command
 *
 * Helper to chroot into a recipe build location with moss-container
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.chroot_command;

import boulder.cli : BoulderCLI;
import boulder.controller;
import mason.build.context : buildContext;
import mason.build.util : executeCommand;
import moss.core : ExitStatus;
import std.experimental.logger;
import std.file : exists, thisExePath;
import std.format : format;
import std.path : absolutePath, buildNormalizedPath, dirName;
public import moss.core.cli;

/**
 * The ChrootCommand is responsible for handling requests to chroot into
 * a stone.yml's build location
 */
@CommandName("chroot") @CommandAlias("cr")
@CommandHelp("Chroot into a recipe's build location using moss-container.")
@CommandUsage("[recipe]")
public struct ChrootCommand
{
    /** Extend BaseCommand with ChrootCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the ChrootCommand where we expect a valid recipe
     * (stone.yml) file
     *
     * Once all validation is passed, we chroot into the recipe's build location
     * using `moss-container`.
     *
     * Params:
     *      argv = arguments passed to command line
     * Returns: ExitStatus.Success on success, ExitStatus.Failure on failure.
     */
    @CommandEntry() int run(ref string[] argv)
    {
        immutable useDebug = this.findAncestor!BoulderCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;

        immutable profile = this.findAncestor!BoulderCLI.profile;
        immutable configDir = this.findAncestor!BoulderCLI.configDir;

        if (argv.length > 1)
        {
            warning("Unexpected number of arguments declared. For help, run boulder chroot -h");
            return ExitStatus.Failure;
        }

        /* Check moss-container exists */
        immutable binDir = thisExePath.dirName;
        immutable containerBinary = binDir.buildNormalizedPath("moss-container").absolutePath;
        if (!containerBinary.exists)
        {
            error(format!"Cannot find `moss-container` at: %s"(containerBinary));
            return ExitStatus.Failure;
        }

        /* Use stone.yml in current dir if no args passed, otherwise the recipe is the first arg */
        immutable recipe = argv.length > 0 ? argv[0] : "stone.yml";
        if (!recipe.exists)
        {
            error(format!"Recipe not found: %s"(recipe));
            return ExitStatus.Failure;
        }

        /* Dummy vars to create a controller */
        immutable outputDirectory = ".";
        immutable unconfined = false;
        immutable compilerCache = false;
        immutable architecture = "native";
        /* Create the controller */
        auto controller = new Controller(outputDirectory, architecture,
                !unconfined, profile, compilerCache, configDir);

        /* Chroot into the recipe */
        controller.chroot(recipe);

        return ExitStatus.Success;
    }
}
