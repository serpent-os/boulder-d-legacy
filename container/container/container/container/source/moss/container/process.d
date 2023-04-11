/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Process helper
 *
 * Provides wrappers around `spawnProcess` which are executed via `fork` with
 * a specified user ID for privilege dropping.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.container.process;

import core.sys.posix.sys.wait;
import core.sys.posix.unistd : _exit, fork, pid_t, setgid, setuid, uid_t;
import std.experimental.logger;
import std.process;
import std.stdio : stderr, stdin, stdout;
import std.string : format, fromStringz, toStringz;
import std.typecons;

import moss.container.context;

/**
 * Chroot to another root filesystem
 */
extern (C) int chroot(const(char*) dir);

/**
 * Simplistic encapsulation of a process.
 */
public struct Process
{

    /**
     * Main executable to launch
     */
    string programName = null;

    /**
     * Additional arguments to the program
     */
    string[] args = null;

    void setUID(int uid)
    {
        this.uid = uid.nullable;
    }

    void setGID(int gid)
    {
        this.gid = gid.nullable;
    }

package:

    /**
     * Fork and run the process
     */
    int run() const
    {
        pid_t child = fork();
        pid_t waiter;
        int status = 0;

        /* We're the fork */
        if (child == 0)
        {
            auto ret = executeChild();
            scope (exit)
            {
                _exit(ret);
            }
            return ret;
        }
        else
        {
            do
            {
                waiter = waitpid(child, &status, WUNTRACED | WCONTINUED);
                if (waiter < 0)
                {
                    import core.stdc.errno : errno;
                    import core.stdc.string : strerror;

                    error(format!"waitpid: Error: %s"(strerror(errno).fromStringz));
                }
            }
            while (!WIFEXITED(status) && !WIFSIGNALED(status));

            return WEXITSTATUS(status);
        }
        assert(0);
    }

private:

    int executeChild() const
    {
        /* Chroot into working system */
        auto ret = chroot(context.rootfs.toStringz);
        assert(ret == 0);

        if (!this.gid.isNull())
        {
            ret = setgid(this.gid.get());
            assert(ret == 0);
        }
        if (!this.uid.isNull())
        {
            ret = setuid(this.uid.get());
            assert(ret == 0);
        }

        auto config = Config.newEnv;
        const(string)[] finalArgs = programName ~ args;

        /* Fakeroot available */
        if (context.fakeroot && context.fakerootBinary != FakerootBinary.None)
        {
            finalArgs = cast(string) context.fakerootBinary ~ finalArgs;
        }

        try
        {
            auto pid = spawnProcess(finalArgs, stdin, stdout, stderr,
                context.environment, config, context.workDir);
            return wait(pid);
        }
        catch (ProcessException px)
        {
            error(format!"Failed to run container: %s"(px.message));
            return 1;
        }
    }

    Nullable!int uid;
    Nullable!int gid;
}
