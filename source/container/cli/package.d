/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

module container.cli;

import std : stderr, stdout;
import std.range;

import moss.core.cli;

@RootCommand @CommandName("container")
@CommandHelp("Manage lightweight containers", `
Use container to manage lightweight containers using Linux namespaces.
container sits between boulder and mason to provide isolation
support, however you can also use container for smoketesting and
general testing.`)
@CommandUsage("[flags] --directory $someRootfs [command]")
public struct ContainerCLI
{
    /** Path where the container resides. */
    @Option("p", "path", "Path where the container resides (will be created if non-existent).")
    string path = null;

    /** Toggle displaying program version. */
    @Option("version", null, "Show program version and exit")
    bool showVersion = false;

    @CommandEntry() int run(ref string[] args)
    {
        if (this.showVersion)
        {
            stdout.writefln!"moss-container, version %s"("0.1");
            stdout.writeln("\nCopyright © 2020-2023 Serpent OS Developers");
            stdout.writeln("Available under the terms of the Zlib license");
            return 0;
        }
        if (this.path.empty)
        {
            stderr.writeln("You must set a directory with the -p flag");
            return 1;
        }
        return 0;
    }
}

@CommandName("create") @CommandAlias("cr")
@CommandHelp("Create a new container",
        "Create a new container in the path specified with the global -p flag.")
public struct CreateCommand
{
}

@CommandName("run") @CommandAlias("ru")
@CommandHelp("Run a command in an existing container",
        "Run a command in the container residing in the path specified with the global -p flag.")
public struct RunCommand
{
    /** Read-only bind mounts */
    @Option("bind-ro", null, "Bind a read-only host location into the container")
    string[string] bindMountsRO;

    /** Read-write bind mounts */
    @Option("bind-rw", null, "Bind a read-write host location into the container")
    string[string] bindMountsRW;

    /** Toggle networking availability */
    @Option("n", "networking", "Enable network access")
    bool networking = false;

    /** Environmental variables for sub processes */
    @Option("s", "set", "Set an environmental variable")
    string[string] environment;

    /** UID to use */
    @Option("root", null, "Set whether the user inside the container is root")
    root = false;

    /** Immediately start at this directory in the container (cwd) */
    @Option("workdir", null, "Start at this working directory in the container (Default: /)")
    string cwd = "/";
}

@CommandName("remote") @CommandAlias("rm")
@CommandHelp("Remove a container",
        "Remove the container in the path specified with the global -p flag.")
public struct RemoveCommand
{
}
