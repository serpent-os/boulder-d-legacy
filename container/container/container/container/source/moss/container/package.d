/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Container encapsulation
 *
 * This module contains the [Container][Container] class which is used as
 * a main entry point for container workloads.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.container;

public import moss.container.device;
public import moss.core.mounts;
public import moss.container.process;
import moss.container.context;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists, remove, symlink, mkdirRecurse, copy;
import std.process;
import std.path : dirName;
import std.stdio : stderr, stdin, stdout;
import std.string : empty, format, toStringz;

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
            Mount("proc", context.joinPath("/proc"), "proc",
                    MountFlags.NoSuid | MountFlags.NoDev | MountFlags.NoExec
                    | MountFlags.RelativeAccessTime),
            Mount("sysfs", context.joinPath("/sys"), "sysfs",
                    MountFlags.NoSuid | MountFlags.NoDev | MountFlags.NoExec
                    | MountFlags.RelativeAccessTime),
            Mount("tmpfs", context.joinPath("/tmp"), "tmpfs",
                    MountFlags.NoSuid | MountFlags.NoDev),

            /* /dev points */
            Mount("tmpfs", context.joinPath("/dev"), "tmpfs",
                    MountFlags.NoSuid | MountFlags.NoExec),
            Mount("tmpfs", context.joinPath("/dev/shm"), "tmpfs",
                    MountFlags.NoSuid | MountFlags.NoDev),
            Mount("devpts", context.joinPath("/dev/pts"), "devpts",
                    MountFlags.NoSuid | MountFlags.NoExec | MountFlags.RelativeAccessTime),
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
    void add(Mount p) @safe
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
            m.target.mkdirRecurse();
            auto err = m.mount();
            if (!err.isNull)
            {
                error(format!"Failed to activate mountpoint: %s, %s"(m.target, err.get.toString));
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

        immutable targetResolve = context.joinPath("etc/resolv.conf");
        if (context.networking && "/etc/resolv.conf".exists && !(targetResolve.exists))
        {
            immutable targetDir = targetResolve.dirName;
            if (!targetDir.exists)
            {
                targetDir.mkdirRecurse();
            }
            info("Installing /etc/resolv.conf for networking");
            "/etc/resolv.conf".copy(targetResolve);
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
            m.unmountFlags = UnmountFlags.Force | UnmountFlags.Detach;
            auto err = m.unmount();
            if (!err.isNull())
            {
                error(format!"Failed to bring down mountpoint: %s, %s"(m, err.get.toString));
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
    Mount[] mountPoints;
}
