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

import std.experimental.logger;
import std.file : exists;
import std.format : format;

import dopt;
import drafter;

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

    @Positional() @Required() @Help("Upstream source URLs")
    string[] upstreams;

    /**
     * Manipulation of recipes
     */
    void run()
    {
        if (outputPath.exists())
        {
            error(format!"Refusing to overwrite existing recipe: %s"(outputPath));
            return;
        }

        auto drafter = new Drafter(outputPath);
        foreach (url; this.upstreams)
        {
            drafter.addSource(url, UpstreamType.Plain);
        }
        drafter.run();

        info(format!"Successfully wrote skeletal recipe %s\n"(outputPath));
        info("The next step is to edit and flesh out the freshly created");
        info(format!"skeletal recipe %s\n"(outputPath));
        info("Once that has been done, an attempt to build it should be");
        info(format!"made with the command: sudo boulder build %s\n"(outputPath));
    }
}
