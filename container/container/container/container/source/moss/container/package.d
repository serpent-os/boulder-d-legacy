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

module moss.container;
import std.stdio : stderr, stdin, stdout;
import std.exception : enforce;
import std.process;
import std.file : exists, remove, symlink;
import std.string : empty, toStringz, format;
import std.path : buildPath;

public import moss.container.device;
public import moss.container.mounts;
public import moss.container.process;

import moss.container.context;

/**
 * A Container is used for the purpose of isolating newly launched processes.
 */
public final class Container
{
    /**
     * Create a new container
     */
    this()
    {
        /* Default mount points */
        mountPoints = [
            MountPoint("proc", "proc",
                    MountOptions.NoSuid | MountOptions.NoDev | MountOptions.NoExec | MountOptions.RelativeAccessTime,
                    "/proc"),
            MountPoint("sysfs", "sysfs",
                    MountOptions.NoSuid | MountOptions.NoDev | MountOptions.NoExec | MountOptions.RelativeAccessTime,
                    "/sys"),
            MountPoint("tmpfs", "tmpfs", MountOptions.NoSuid | MountOptions.NoDev, "/tmp"),

            /* /dev points */
            MountPoint("tmpfs", "tmpfs", MountOptions.NoSuid | MountOptions.NoExec, "/dev"),
            MountPoint("tmpfs", "tmpfs", MountOptions.NoSuid | MountOptions.NoDev, "/dev/shm"),
            MountPoint("devpts", "devpts",
                    MountOptions.NoSuid | MountOptions.NoExec | MountOptions.RelativeAccessTime,
                    "/dev/pts"),
        ];
    }

    /**
     * Add a process to this container
     */
    void add(Process p) @safe
    {
        processes ~= p;
    }

    /**
     * Add a mountpoint to the system
     */
    void add(MountPoint p) @safe
    {
        mountPoints ~= p;
    }

    /**
     * Run the associated args (cmdline) with various settings in place
     */
    int run() @system
    {
        import std.algorithm : remove;

        scope (exit)
        {
            downMounts();
        }

        /* Setup mounts */
        foreach (ref m; mountPoints)
        {
            if (!m.up())
            {
                stderr.writeln("Failed to activate mountpoint: ", m.target);
                /* Remove the mountpoint now */
                mountPoints = mountPoints.remove!((m2) => m.target == m2.target);
                return 1;
            }
        }

        configureDevfs();

        /* Inspect now the environment is ready */
        if (!context.inspectRoot())
        {
            return 1;
        }

        auto ret = 0;
        /* TODO: Handle exit code for more processes */
        foreach (p; processes)
        {
            ret = p.run();
        }

        return ret;
    }

private:

    void downMounts()
    {
        foreach_reverse (ref m; mountPoints)
        {
            if (!m.down())
            {
                stderr.writeln("Failed to bring down mountpoint: ", m);
            }
        }
    }

    /**
     * Configure the /dev tree to be valid
     */
    void configureDevfs()
    {

        auto symlinkSources = [
            "/proc/self/fd", "/proc/self/fd/0", "/proc/self/fd/1",
            "/proc/self/fd/2", "pts/ptmx"
        ];

        auto symlinkTargets = [
            "/dev/fd", "/dev/stdin", "/dev/stdout", "/dev/stderr", "/dev/ptmx"
        ];

        static DeviceNode[] nodes = [
            DeviceNode("/dev/null", S_IFCHR | octal!666, mkdev(1, 3)),
            DeviceNode("/dev/zero", S_IFCHR | octal!666, mkdev(1, 5)),
            DeviceNode("/dev/full", S_IFCHR | octal!666, mkdev(1, 7)),
            DeviceNode("/dev/random", S_IFCHR | octal!666, mkdev(1, 8)),
            DeviceNode("/dev/urandom", S_IFCHR | octal!666, mkdev(1, 9)),
            DeviceNode("/dev/tty", S_IFCHR | octal!666, mkdev(5, 0)),
        ];

        /* Link sources to targets */
        foreach (i; 0 .. symlinkSources.length)
        {
            auto source = symlinkSources[i];
            auto target = context.joinPath(symlinkTargets[i]);

            /* Remove old target */
            if (target.exists)
            {
                target.remove();
            }

            /* Link source to target */
            symlink(source, target);
        }

        /* Create our nodes */
        foreach (ref n; nodes)
        {
            n.create();
        }
    }

    Process[] processes;
    MountPoint[] mountPoints;
}
