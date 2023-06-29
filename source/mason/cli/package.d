/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.cli
 *
 * Module namespace imports & MasonCLI definition
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.cli;

import std.sumtype;

import dopt;
import mason.cli.cmdbuild;

private alias Subcommands = SumType!(Build);


/**
 * The MasonCLI type holds some global configuration bits
 */
@Command("mason")
@Help("Build stone packages using YML recipes.")
private struct MasonCLI
{
    /** Select an alternative output location than the current working directory */
    @Option() @Short("o") @Long("output") @Help("Directory to store build results")
    string outputDirectory = ".";

    /** Override the build directory to one containing the prepared sources */
    @Option() @Short("b") @Long("buildDir") @Help("Set the build directory")
    string buildDir = null;

    /** When set to true, we enable debug output */
    @Option() @Short("d") @Long("debug") @Help("Enable debugging output")
    bool debugMode = false;

    @Subcommand()
    Subcommands subcommand;
}

int run(string[] args)
{
    return 0;
}
