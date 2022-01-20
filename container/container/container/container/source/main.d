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
import core.sys.posix.sys.stat : umask;
import std.conv : octal;
import std.getopt;
import std.file : exists, isDir;
import std.string : empty;
import std.stdio : stderr;
import core.sys.posix.unistd : geteuid;

/**
 * Main entry point into moss-container
 */
int main(string[] args)
{
    umask(octal!22);
    string rootfsDir = null;
    bool fakeroot = false;
    bool networking = false;

    auto opts = getopt(args, std.getopt.config.bundling, "directory|d",
            &rootfsDir, "fakeroot|f", &fakeroot, "networking|n", &networking);

    if (opts.helpWanted)
    {
        defaultGetoptPrinter("Usage: ", opts.options);
        return 0;
    }

    /* Ensure rootfs directory set */
    if (rootfsDir.empty)
    {
        stderr.writeln("You must set a directory with the -d option");
        return 1;
    }

    if (!rootfsDir.exists || !rootfsDir.isDir)
    {
        stderr.writefln("The directory specified does not exist: %s", rootfsDir);
    }

    /* Set the rootfs */
    context.rootfs = rootfsDir;

    /* Ensure we're running as root */
    if (geteuid() != 0)
    {
        stderr.writefln("%s: Needs to run as root", args[0]);
        return 1;
    }

    string[] commandLine = args.length > 0 ? args[1 .. $] : null;
    if (commandLine.length < 1)
    {
        commandLine = ["/bin/bash", "--login"];
    }

    string programName = commandLine[0];
    string[] programArgs = commandLine[0].length > 0 ? commandLine[1 .. $] : null;

    context.fakeroot = fakeroot;
    context.workDir = "/";
    context.environment["PATH"] = "/usr/bin:/bin";

    auto c = new Container();
    c.networking = networking;
    c.add(Process(programName, programArgs));
    return c.run();
}
