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
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
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
