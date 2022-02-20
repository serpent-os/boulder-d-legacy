/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2022 Serpent OS Developers
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
}
