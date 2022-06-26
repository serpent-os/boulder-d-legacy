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

module mason.cli.build_command;

public import moss.core.cli;
import moss.core;
import std.stdio;
import mason.build.context;
import mason.build.controller;
import mason.cli : MasonCLI;
import std.parallelism : totalCPUs;
import moss.core.logging;

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
public struct BuildCommand
{
    /** Extend BaseCommand with BuildCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the BuildCommand. We expect a list of paths that
     * contain "stone.yml" formatted build description files. For each path
     * we encounter, we initially check the validity and existence.
     *
     * Once all validation is passed, we begin building all of the passed
     * file paths into packages.
     */
    @CommandEntry() int run(ref string[] argv)
    {
        /// FIXME
        ///immutable useDebug = pt.findAncestor!MasonCLI.debugMode;
        ///globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;
        configureLogging();
        globalLogLevel = LogLevel.trace;

        import std.exception : enforce;

        auto outputDir = pt.findAncestor!(MasonCLI).outputDirectory;
        auto buildDir = pt.findAncestor!(MasonCLI).buildDir;

        buildContext.outputDirectory = outputDir;
        buildContext.jobs = jobs;

        /* Auto discover job count */
        if (buildContext.jobs < 1)
        {
            buildContext.jobs = totalCPUs - 1;
        }
        buildContext.rootDir = buildDir;

        auto controller = new BuildController(architecture);
        foreach (specURI; argv)
        {
            if (!controller.build(specURI))
            {
                return ExitStatus.Failure;
            }
        }

        return ExitStatus.Success;
    }

    /** Specify the number of build jobs to execute in parallel. */
    @Option("j", "jobs", "Set the number of parallel build jobs (0 = automatic)") int jobs = 0;

    /** Set the architecture to build for. Defaults to native */
    @Option("a", "architecture", "Target architecture for the build") string architecture = "native";
}
