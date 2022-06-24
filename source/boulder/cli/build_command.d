/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source builds must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.cli.build_command;

public import moss.core.cli;
import moss.core;
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

        /* Ensure root permissions */
        if (geteuid() != 0)
        {
            error("This program must be run with root permissions");
            return ExitStatus.Failure;
        }

        auto controller = new Controller();
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
    @Option("u", "unconfined", "Build directly on host without container or dependencies") bool unsafeBuild = false;
}
