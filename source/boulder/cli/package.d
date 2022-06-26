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

module boulder.cli;

public import moss.core.cli;
public import boulder.cli.build_command;
public import boulder.cli.new_command;
public import boulder.cli.version_command;

/**
 * The BoulderCLI type holds some global configuration bits
 */
@RootCommand @CommandName("boulder")
@CommandHelp("boulder - produce packages for moss", "A core component of the Serpent tooling")
@CommandUsage("[--args] [command]")
public struct BoulderCLI
{
    /** Extend BaseCommand to give a root command for our CLI */
    BaseCommand pt;
    alias pt this;

    /** When set to true, we enable debug output */
    @Option("d", "debug", "Enable debugging output") bool debugMode = false;
}
