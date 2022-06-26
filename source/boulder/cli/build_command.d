/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Module Name (use e.g. 'moss.core.foo.bar')
 *
 * Module Description (FIXME)
 *
 * In package.d files containing only imports and nothing else,
 * 'Module namespace imports.' is sufficient description.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.build_command;

public import moss.core.cli;
import moss.core;
import std.file : exists;
import std.stdio;
import boulder.cli : BoulderCLI;
import boulder.controller;
import core.sys.posix.unistd : geteuid;
import std.experimental.logger;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@CommandName("build") @CommandAlias("bi")
@CommandHelp("Build a package",
        "Build a binary package from the given package specification file. It will
be built using the locally available build dependencies and the resulting
binary packages (.stone) will be emitted to the output directory, which
defaults to the current working directory.")
@CommandUsage("[spec]")
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

        if (!outputDirectory.exists)
        {
            errorf("Output directory does not exist: %s", outputDirectory);
            return ExitStatus.Failure;
        }

        /* Ensure root permissions */
        if (geteuid() != 0)
        {
            error("This program must be run with root permissions");
            return ExitStatus.Failure;
        }

        auto controller = new Controller(outputDirectory, architecture, !unconfined);
        foreach (recipe; argv)
        {
            controller.build(recipe);
        }
        return ExitStatus.Success;
    }

    /** Select an alternative output location than the current working directory */
    @Option("o", "output", "Directory to store build results") string outputDirectory = ".";

    /** Specify the number of build jobs to execute in parallel. */
    @Option("j", "jobs", "Set the number of parallel build jobs (0 = automatic)") int jobs = 0;

    /** Bypass container/moss logic and build directly on host (invoke carver) */
    @Option("u", "unconfined", "Build directly on host without container or dependencies") bool unconfined = false;

    /** Set the architecture to build for. Defaults to native */
    @Option("a", "architecture", "Target architecture for the build") string architecture = "native";
}
