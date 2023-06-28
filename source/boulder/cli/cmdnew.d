/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.new_command
 *
 * Implements the `boulder new` subcommand
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.cmdnew;

import std.algorithm : each;
import std.experimental.logger;
import std.file : exists;
import std.format : format;

import dopt;
import drafter;
import moss.core;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@Command()
@Help("Create skeletal stone.yml recipe from source archive URI")
public struct New
{
    /** Where to output the YML file */
    @Option() @Short("o") @Long("output") @Help("Location to output generated build recipe")
    string outputPath = "stone.yml";

    /**
     * Manipulation of recipes
     */
    int run(ref string[] argv)
    {
        immutable useDebug = this.findAncestor!BoulderCLI.debugMode;
        globalLogLevel = useDebug ? LogLevel.trace : LogLevel.info;

        if (argv == null)
        {
            warning("No arguments specified. For help, run boulder new -h");
            return ExitStatus.Failure;
        }

        if (outputPath.exists)
        {
            error(format!"Refusing to overwrite existing recipe: %s"(outputPath));
            return ExitStatus.Failure;
        }

        auto drafter = new Drafter(outputPath);
        argv.each!((a) => drafter.addSource(a, UpstreamType.Plain));
        auto exitStatus = drafter.run();
        if (exitStatus == ExitStatus.Success)
        {
            info(format!"Successfully wrote skeletal recipe %s\n"(outputPath));
            info("The next step is to edit and flesh out the freshly created");
            info(format!"skeletal recipe %s\n"(outputPath));
            info("Once that has been done, an attempt to build it should be");
            info(format!"made with the command: sudo boulder build %s\n"(outputPath));
        }
        drafter.destroy(); /* Ensure we flush & close */

        return exitStatus;
    }
}
