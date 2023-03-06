/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Container encapsulation
 *
 * This module contains the [Container][Container] class which is used as
 * a main entry point for container workloads.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.container;

public import moss.container.device;
public import moss.core.mounts;
public import moss.container.process;
import moss.container.context;
import std.exception : enforce;
import std.experimental.logger;
import std.file : copy, exists, mkdirRecurse, remove, symlink, write;
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
            Mount("", context.joinPath("/proc"), "proc",
                    MountFlags.NoSuid | MountFlags.NoDev | MountFlags.NoExec
                    | MountFlags.RelativeAccessTime),
            Mount("/sys", context.joinPath("/sys"), "",
                    MountFlags.Bind | MountFlags.Rec | MountFlags.ReadOnly),
            Mount("", context.joinPath("/tmp"), "tmpfs", MountFlags.NoSuid | MountFlags.NoDev)
        ];

        /* /dev points */
        auto dev = Mount("", context.joinPath("/dev"), "tmpfs",
                MountFlags.NoSuid | MountFlags.NoExec);
        dev.setData("mode=777".toStringz());
        mountPoints ~= [
            dev,
            Mount("", context.joinPath("/dev/shm"), "tmpfs",
                    MountFlags.NoSuid | MountFlags.NoDev),
            Mount("", context.joinPath("/dev/pts"), "devpts",
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
            m.unmountFlags = UnmountFlags.Detach;
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

        /* Can't use mknod because we want to support unprivileged containers
         * like Podman or Docker. Let's bind mount existing nodes to circumvent
         * this limitation.
         */
        Mount[] nodes = [
            Mount("/dev/null", context.joinPath("/dev/null"), "", MountFlags.Bind),
            Mount("/dev/zero", context.joinPath("/dev/zero"), "", MountFlags.Bind),
            Mount("/dev/full", context.joinPath("/dev/full"), "", MountFlags.Bind),
            Mount("/dev/random", context.joinPath("/dev/random"), "", MountFlags.Bind),
            Mount("/dev/urandom", context.joinPath("/dev/urandom"), "",
                    MountFlags.Bind),
            Mount("/dev/tty", context.joinPath("/dev/tty"), "", MountFlags.Bind),
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
            write(n.target, null); /* Create the empty file first. */
            n.mount();
        }
    }

    Process[] processes;
    Mount[] mountPoints;
}
