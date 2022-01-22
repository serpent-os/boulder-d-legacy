/*
 * This file is part of moss-container.
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

module main;

import moss.container;
import std.path : buildPath;

import moss.container.context;
import moss.container.mounts;
import core.sys.posix.sys.stat : umask;
import std.conv : octal;
import std.file : exists, isDir;
import std.string : empty;
import std.stdio : stderr, stdout;
import core.sys.posix.unistd : geteuid;

import moss.core.cli;

/**
 * The BoulderCLI type holds some global configuration bits
 */
@RootCommand @CommandName("moss-container")
@CommandHelp("Manage lightweight containers", `
Use moss-container to manage lightweight containers using Linux namespaces.
Typically moss-container sits between boulder and mason to provide isolation
support, however you can also use moss-container for smoketesting and
general testing.`)
@CommandUsage("[flags] --directory $someRootfs [command]")

public struct ContainerCLI
{
    /** Extend BaseCommand to give a root command for our CLI */
    BaseCommand pt;
    alias pt this;

    @Option("b", "bind", "Bind a host location into the container")
    string[string] bindMounts;

    @Option("d", "directory", "Directory to find a root filesystem")
    string rootfsDir = null;

    @Option("f", "fakeroot", "Enable fakeroot integration")
    bool fakeroot = false;

    @Option("n", "networking", "Enable network access")
    bool networking = false;

    @Option("v", "version", "Show program version and exit")
    bool showVersion = false;

    @Option("s", "set", "Set an environmental variable")
    string[string] environment;

    @CommandEntry() int run(ref string[] args)
    {
        umask(octal!22);

        if (showVersion)
        {
            stdout.writefln("moss-container, version %s", "0.0.0");
            stdout.writeln("\nCopyright © 2020-2022 Serpent OS Developers");
            stdout.writeln("Available under the terms of the ZLib license");
            return 0;
        }

        if (rootfsDir.empty)
        {
            stderr.writeln("You must set a directory with the -d option");
            return 1;
        }

        if (!rootfsDir.exists || !rootfsDir.isDir)
        {
            stderr.writefln("The directory specified does not exist: %s", rootfsDir);
        }

        /* Setup rootfs - ensure we're running as root too */
        context.rootfs = rootfsDir;
        if (geteuid() != 0)
        {
            stderr.writeln("You must run moss-container as root");
            return 1;
        }

        string[] commandLine = args;
        if (commandLine.length < 1)
        {
            commandLine = ["/bin/bash", "--login"];
        }

        string programName = commandLine[0];
        string[] programArgs = commandLine[0].length > 0 ? commandLine[1 .. $] : null;

        context.fakeroot = fakeroot;
        context.workDir = "/";
        context.environment = environment;
        if (!("PATH" in context.environment))
        {
            context.environment["PATH"] = "/usr/bin:/bin";
        }

        auto c = new Container();
        c.networking = networking;
        c.add(Process(programName, programArgs));

        /* Work the bindmounts in */
        foreach (source, target; bindMounts)
        {
            auto mnt = MountPoint(source, null, MountOptions.Bind, target);
            c.add(mnt);
        }
        return c.run();
    }
}

int main(string[] args)
{
    auto clip = cliProcessor!ContainerCLI(args);
    return clip.process(args);
}
