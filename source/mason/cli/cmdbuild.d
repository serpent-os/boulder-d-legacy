/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.cli.build_command
 *
 * Implements the `mason build` subcommand
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.cli.cmdbuild;

import core.sys.posix.unistd;
import std.experimental.logger;
import std.format : format;
import std.parallelism : totalCPUs;

import dopt;
import mason.build.context;
import mason.build.controller;
import mason.cli : MasonCLI;
import moss.core;
import moss.core.logger;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@Command() /*@Alias("bi")*/
@Help(`Build a binary package from the given package specification file.
It will be built using the locally available build dependencies and the
resulting binary packages (.stone) will be emitted to the output directory,
which defaults to the current working directory.`)
public struct Build
{
    /** Specify the number of build jobs to execute in parallel. */
    @Option() @Short("j") @Long("jobs") @Help("Set the number of parallel build jobs (0 = automatic)")
    int jobs = 0;

    /** Set the architecture to build for. Defaults to native */
    @Option() @Short("a") @Long("architecture") @Help("Target architecture for the build")
    string architecture = "native";

    /** Enable compiler caching */
    @Option() @Short("c") @Long("compiler-cache") @Help("Enable compiler caching")
    bool compilerCache = false;

    /**
     * Main entry point into the BuildCommand. We expect a list of paths that
     * contain "stone.yml" formatted build description files. For each path
     * we encounter, we initially check the validity and existence.
     *
     * Once all validation is passed, we begin building all of the passed
     * file paths into packages.
     */
    int run(ref string[] argv)
    {
        /* configureLogger resets the globalLogLevel to LogLevel.info */
        if (isatty(0) && isatty(1))
        {
            configureLogger(ColorLoggerFlags.Color | ColorLoggerFlags.Timestamps);
        }
        else
        {
            configureLogger(ColorLoggerFlags.Timestamps);
        }

        immutable useDebug = this.findAncestor!MasonCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;
        info(format!"mason log level set to: %s"(globalLogLevel));

        auto outputDir = pt.findAncestor!(MasonCLI).outputDirectory;
        auto buildDir = pt.findAncestor!(MasonCLI).buildDir;

        buildContext.outputDirectory = outputDir;
        buildContext.jobs = jobs;
        buildContext.compilerCache = compilerCache;

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
                trace(format!"Could not build '%s'"(specURI));
                return ExitStatus.Failure;
            }
        }

        return ExitStatus.Success;
    }
}
