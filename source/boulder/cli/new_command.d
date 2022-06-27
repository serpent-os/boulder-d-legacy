/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.new_command
 *
 * Implements the `boulder new` subcommand
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.new_command;

public import moss.core.cli;
import boulder.cli : BoulderCLI;
import drafter;
import moss.core;
import std.algorithm : each;
import std.file : exists;
import std.experimental.logger;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@CommandName("new")
@CommandHelp("Create skeletal recipe")
@CommandUsage("[-a $URL] [-g $GITURL]")
public struct NewCommand
{
    /** Extend BaseCommand with NewCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Manipulation of recipes
     */
    @CommandEntry() int run(ref string[] argv)
    {
        immutable useDebug = this.findAncestor!BoulderCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;

        if (outputPath.exists)
        {
            errorf("Refusing to overwrite recipe: %s", outputPath);
            return ExitStatus.Failure;
        }

        auto drafter = new Drafter(outputPath);
        argv.each!((a) => drafter.addSource(a, UpstreamType.Plain));
        drafter.run();
        drafter.destroy(); /* Ensure we flush & close */
        return ExitStatus.Failure;
    }

    /** Where to output the YML file */
    @Option("o", "output", "Location to output generated build recipe")
    string outputPath = "stone.yml";
}
