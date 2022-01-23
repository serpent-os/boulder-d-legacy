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
import std.conv : octal;
import std.file : exists, isDir;
import std.exception : enforce;
import std.string : empty;
import std.stdio : stderr, stdout;
import core.stdc.stdlib : _Exit;
import core.sys.posix.unistd : geteuid, fork;
import core.sys.posix.sys.wait;
import core.sys.posix.sys.stat : umask;
import core.sys.linux.sched;

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

    @Option("bind-ro", null, "Bind a read-only host location into the container")
    string[string] bindMountsRO;

    @Option("bind-rw", null, "Bind a read-write host location into the container")
    string[string] bindMountsRW;

    @Option("d", "directory", "Directory to find a root filesystem")
    string rootfsDir = null;

    @Option("f", "fakeroot", "Enable fakeroot integration")
    bool fakeroot = false;

    @Option("n", "networking", "Enable network access")
    bool networking = false;

    @Option("s", "set", "Set an environmental variable")
    string[string] environment;

    @Option("version", null, "Show program version and exit")
    bool showVersion = false;

    @CommandEntry() int run(ref string[] args)
    {
        umask(octal!22);

        if (showVersion)
        {
            stdout.writefln("moss-container, version %s", "0.1");
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

        if (geteuid() != 0)
        {
            stderr.writeln("You must run moss-container as root");
            //return 1;
        }

        /* Setup rootfs - ensure we're running as root too */
        context.rootfs = rootfsDir;
        context.fakeroot = fakeroot;
        context.workDir = "/";
        context.environment = environment;
        if (!("PATH" in context.environment))
        {
            context.environment["PATH"] = "/usr/bin:/bin";
        }

        return enterNamespace(args);
    }

    /**
     * Perform actual container run
     */
    int runContainer(ref string[] args)
    {
        string[] commandLine = args;
        if (commandLine.length < 1)
        {
            commandLine = ["/bin/bash", "--login"];
        }

        string programName = commandLine[0];
        string[] programArgs = commandLine[0].length > 0 ? commandLine[1 .. $] : null;

        auto c = new Container();
        c.add(Process(programName, programArgs));

        /* Work the RO bindmounts in */
        foreach (source, target; bindMountsRO)
        {
            c.add(MountPoint(source, null, MountOptions.Bind | MountOptions.ReadOnly, target));
        }
        /* Likewise for RW mounts */
        foreach (source, target; bindMountsRW)
        {
            c.add(MountPoint(source, null, MountOptions.Bind, target));
        }
        return c.run();
    }

    void detachNamespace()
    {
        auto flags = CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWIPC;
        if (!networking)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }

        auto ret = unshare(flags);
        enforce(ret == 0, "Failed to detach namespace");
    }

    /**
     * Enter the namespace. Will vfork() and execute runContainer()
     */
    int enterNamespace(ref string[] args)
    {
        auto childPid = fork();
        int status = 0;
        int ret = 0;

        detachNamespace();

        /* Run child process */
        if (childPid == 0)
        {
            _Exit(runContainer(args));
        }

        do
        {
            ret = waitpid(childPid, &status, WUNTRACED | WCONTINUED);
            enforce(ret >= 0);
        }
        while (!WIFEXITED(status) && !WIFSIGNALED(status));

        return WEXITSTATUS(status);
    }
}

int main(string[] args)
{
    auto clip = cliProcessor!ContainerCLI(args);
    return clip.process(args);
}
