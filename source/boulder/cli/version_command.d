/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli.version_command
 *
 * Implements the `boulder version` subcommnd
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli.version_command;

public import moss.core.cli;
import moss.core;

/**
 * The VersionCommand is just a simplistic printer for the version
 */
@CommandName("version")
@CommandHelp("Show the program version and exit")
public struct VersionCommand
{
    /** Extend BaseCommand for VersionCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Upon execution, we simply dump the program + library version to
     * stdout, and exit with a successful error code.
     */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.stdio : writefln, writeln;

        writefln!"boulder, version %s"(moss.core.Version);
        writeln("\nCopyright © 2020-2022 Serpent OS Developers");
        writeln("Available under the terms of the Zlib license");
        return ExitStatus.Success;
    }
}
