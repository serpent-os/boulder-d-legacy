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

public import moss.core.cli;
public import mason.cli.build_command;

/**
 * The MasonCLI type holds some global configuration bits
 */
@RootCommand @CommandName("mason")
@CommandHelp("mason - build stone packages using YML recipes")
@CommandUsage("[--args] [command]")
public struct MasonCLI
{
    /** Extend BaseCommand to give a root command for our CLI */
    BaseCommand pt;
    alias pt this;

    /** Select an alternative output location than the current working directory */
    @Option("o", "output", "Directory to store build results") string outputDirectory = ".";

    /** Override the build directory to one containing the prepared sources */
    @Option("b", "buildDir", "Set the build directory") string buildDir = null;

    /** When set to true, we enable debug output */
    @Option("d", "debug", "Enable debugging output") bool debugMode = false;
}
