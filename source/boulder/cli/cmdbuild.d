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

module boulder.cli.cmdbuild;

import std.experimental.logger;
import std.range : empty;

import boulder.controller;
import dopt;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@Command() /*@Alias("bi")*/
@Help(`Build a binary .stone package
Using the given package recipe file (defaults to stone.yml), a binary
.stone package will be built using the locally available build dependencies and
the resulting binary artefact will be emitted to the output directory, which
defaults to the current working directory.`)
package struct Build
{
    /** Select an alternative output location than the current working directory */
    @Option() @Short("o") @Long("output") @Help("Directory to store build results")
    string outputDirectory = ".";

    /** Specify the number of build jobs to execute in parallel. */
    @Option() @Short("j") @Long("jobs") @Help("Set the number of parallel build jobs (0 = automatic)")
    int jobs = 0;

    /** Bypass container/moss logic and build directly on host (invoke carver) */
    @Option() @Short("u") @Long("unconfined") @Help("Build directly on host without container or dependencies")
    bool unconfined = false;

    /** Set the architecture to build for. Defaults to native */
    @Option() @Short("a") @Long("architecture") @Help("Target architecture for the build")
    string architecture = "native";

    /** Enable compiler caching */
    @Option() @Short("c") @Long("compiler-cache") @Help("Enable compiler caching")
    bool compilerCache = false;

    @Positional() @Help("Recipe path")
    string recipePath;

    /**
     * Main entry point into the BuildControlCommand. We expect a list of paths that
     * contain "stone.yml" formatted build description files. For each path
     * we encounter, we initially check the validity and existence.
     *
     * Once all validation is passed, we begin building all of the passed
     * file paths into packages.
     */
    void run(string resourcePath, string profile)
    {
        if (this.recipePath.empty())
        {
            trace("No recipe specified, building stone.yml recipe in current directory");
            this.recipePath = "stone.yml";
        }
        auto controller = new Controller(
            this.outputDirectory,
            this.architecture,
            !this.unconfined,
            profile,
            this.compilerCache,
            resourcePath,
        );
        controller.build(this.recipePath);
    }
}
