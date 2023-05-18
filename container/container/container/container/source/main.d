/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Main entry point
 *
 * Provides the main entry point into the `moss-container` binary along
 * with some CLI parsing and container namespace initialisation.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module main;

import core.stdc.stdlib : _Exit;
import core.sys.linux.sched;
import core.sys.posix.sys.stat : umask;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd : fork, geteuid, isatty;
import std.conv : octal;
import std.exception : enforce;
import std.file : exists, isDir;
import std.stdio : stderr, stdout;
import std.string : empty, format;

import moss.container;
import moss.container.context;
import moss.container.filesystem;
import moss.container.process;
import moss.core.cli;
import moss.core.logger;
import moss.core.mounts;

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

    /** Read-only bind mounts */
    @Option("bind-ro", null, "Bind a read-only host location into the container")
    string[string] bindMountsRO;

    /** Read-write bind mounts */
    @Option("bind-rw", null, "Bind a read-write host location into the container")
    string[string] bindMountsRW;

    /** Root filesystem directory */
    @Option("d", "directory", "Directory to find a root filesystem")
    string rootfsDir = null;

    /** Work directory. */
    @Option("o", "overlayroot", "OverlayFS parent directory (will be created if non-existent)")
    string overlayRoot = null;

    /** Immediately start at this directory in the container (cwd) */
    @Option("workdir", null, "Start at this working directory in the container (Default: /)")
    string cwd = "/";

    /** Toggle fakeroot use */
    @Option("f", "fakeroot", "Enable fakeroot integration")
    bool fakeroot = false;

    /** Toggle networking availability */
    @Option("n", "networking", "Enable network access")
    bool networking = false;

    /** Environmental variables for sub processes */
    @Option("s", "set", "Set an environmental variable")
    string[string] environment;

    /** UID to use */
    @Option("root", null, "Set whether the user inside the container is root")
    root = false;

    /** Toggle displaying program version */
    @Option("version", null, "Show program version and exit")
    bool showVersion = false;

    /**
     * Begin container dispatch cycle
     *
     * Prior to container run the namespace will be unshared already
     * and we will be executing in a namespaced fork.
     *
     * Params:
     *      args = Command line arguments for the process
     * Returns: Exit code of the primary containerised process
     */
    @CommandEntry() int run(ref string[] args)
    {
        /// FIXME: make configurable (-d is currently used for destination)
        if (isatty(0) && isatty(1))
        {
            configureLogger(ColorLoggerFlags.Color | ColorLoggerFlags.Timestamps);
        }
        else
        {
            configureLogger(ColorLoggerFlags.Timestamps);
        }
        globalLogLevel = LogLevel.trace;

        umask(octal!22);

        if (showVersion)
        {
            stdout.writefln!"moss-container, version %s"("0.1");
            stdout.writeln("\nCopyright © 2020-2023 Serpent OS Developers");
            stdout.writeln("Available under the terms of the Zlib license");
            return 0;
        }

        if (rootfsDir.empty)
        {
            stderr.writeln("You must set a directory with the -d option");
            return 1;
        }

        if (overlayRoot.empty)
        {
            stderr.writeln("You must choose an OverlayFS parent directory path with the -o option");
            return 1;
        }

        if (!rootfsDir.exists || !rootfsDir.isDir)
        {
            stderr.writefln!"The directory specified does not exist: %s"(rootfsDir);
        }

        /* Setup rootfs - ensure we're running as root too */
        context.rootfs = rootfsDir;
        context.fakeroot = fakeroot;
        context.workDir = cwd;
        context.environment = environment;
        context.networking = networking;
        if (!("PATH" in context.environment))
        {
            context.environment["PATH"] = "/usr/bin:/bin";
        }

        return runContainer(args);
    }

    /**
     * Bring up the child container
     *
     * Pass off to the [Container][Container] class for bringup.
     *
     * Params:
     *      args = Command line arguments for the process
     * Returns: Exit code of the primary containerised process
     */
    int runContainer(ref string[] args)
    {
        auto fs = Filesystem.defaultFS(this.rootfsDir, networking);
        foreach (source, target; bindMountsRO)
        {
            fs.extraMounts ~= FileMount.bindRO(source, target);
        }
        foreach (source, target; bindMountsRW)
        {
            fs.extraMounts ~= FileMount.bindRW(source, target);
        }

        string[] commandLine = args;
        if (commandLine.length < 1)
        {
            commandLine = ["/bin/bash", "--login"];
        }
        string programName = commandLine[0];
        string[] programArgs = commandLine[0].length > 0 ? commandLine[1 .. $] : null;
        auto proc = Process(programName, programArgs);

        auto cont = Container(fs);
        cont.withNetworking(networking);
        cont.withRootPrivileges(root);
        cont.setProcesses([proc]);

        return cont.run();
    }
}

int main(string[] args)
{
    auto clip = cliProcessor!ContainerCLI(args);
    return clip.process(args);
}
