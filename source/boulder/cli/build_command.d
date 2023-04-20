/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.build_command
 *
 * Implements the `boulder build` subcommand
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.build_command;

import boulder.cli : BoulderCLI;
import boulder.controller;
import moss.core;
import std.experimental.logger;
import std.file : exists;
import std.format : format;
import std.stdio;
public import moss.core.cli;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@CommandName("build") @CommandAlias("bi")
@CommandHelp("Build a binary .stone package",
        "Using the given package recipe file (defaults to stone.yml), a binary
.stone package will be built using the locally available build dependencies and
the resulting binary artefact will be emitted to the output directory, which
defaults to the current working directory.")
@CommandUsage("[recipe]")
public struct BuildControlCommand
{
    /** Extend BaseCommand with BuildControlCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the BuildControlCommand. We expect a list of paths that
     * contain "stone.yml" formatted build description files. For each path
     * we encounter, we initially check the validity and existence.
     *
     * Once all validation is passed, we begin building all of the passed
     * file paths into packages.
     */
    @CommandEntry() int run(ref string[] argv)
    {
        immutable useDebug = this.findAncestor!BoulderCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;
        ExitStatus res;

        immutable profile = this.findAncestor!BoulderCLI.profile;
        immutable configDir = this.findAncestor!BoulderCLI.configDir;

        if (!outputDirectory.exists)
        {
            error(format!"Output directory does not exist: %s"(outputDirectory));
            return ExitStatus.Failure;
        }

        auto controller = new Controller(outputDirectory, architecture,
                !unconfined, profile, compilerCache, configDir);

        /* Require a recipe to continue */
        if (argv == null && !"stone.yml".exists)
        {
            error("No recipe specified and no stone.yml file found in current directory");
            return ExitStatus.Failure;
        }

        if (argv.length > 1)
        {
            error(format!"Unexpected number of arguments, got %s. Expected one recipe file."(
                    argv.length));
            return ExitStatus.Failure;
        }

        /* When no recipes are specified, build stone.yml recipe in current directory if it exists */
        if (argv == null && "stone.yml".exists)
        {
            trace("No recipe specified, building stone.yml recipe found in current directory");
            res = controller.build("stone.yml");
        }
        else
        {
            res = controller.build(argv[0]);
        }
        return res;
    }

    /** Select an alternative output location than the current working directory */
    @Option("o", "output", "Directory to store build results") string outputDirectory = ".";

    /** Specify the number of build jobs to execute in parallel. */
    @Option("j", "jobs", "Set the number of parallel build jobs (0 = automatic)") int jobs = 0;

    /** Bypass container/moss logic and build directly on host (invoke carver) */
    @Option("u", "unconfined", "Build directly on host without container or dependencies") bool unconfined = false;

    /** Set the architecture to build for. Defaults to native */
    @Option("a", "architecture", "Target architecture for the build") string architecture = "native";

    /** Enable compiler caching */
    @Option("c", "compiler-cache", "Enable compiler caching") bool compilerCache = false;
}
