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
 * 2. Altered source builds must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.cli.new_command;

public import moss.core.cli;
import boulder.cli : BoulderCLI;
import drafter;
import moss.core;
import std.algorithm : each;
import std.stdio;
import std.file : exists;
import std.string : empty;

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
        if ("stone.yml".exists && writeLocation == "stone.yml")
        {
            stderr.writeln("stone.yml exists - aborting");
            return ExitStatus.Failure;
        }

        auto drafter = new Drafter(writeLocation);

        archives.each!((a) => drafter.addSource(a, UpstreamType.Plain));
        vcsSources.each!((a) => drafter.addSource(a, UpstreamType.Git));
        drafter.run();
        drafter.destroy(); /* Ensure we flush & close */
        return ExitStatus.Failure;
    }

    @Option("a", "archive", "URL to an archive to use")
    string[] archives;

    @Option("g", "git", "Git source to utilise")
    string[] vcsSources;

    @Option("w", "write-to", "Location to output generated build recipe")
    string writeLocation = "stone.yml";
}
