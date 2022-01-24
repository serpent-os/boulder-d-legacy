/* SPDX-License-Identifier: Zlib */

/**
 * Process helper
 *
 * Provides wrappers around `spawnProcess` which are executed via `fork` with
 * a specified user ID for privilege dropping.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */
module moss.container.process;

import core.sys.posix.sys.wait;
import core.sys.posix.unistd : _exit, fork, pid_t, setgid, setuid, uid_t;
import moss.container.context;
import std.process;
import std.stdio : stderr, stdin, stdout;
import std.string : toStringz;

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

package:

    /**
     * Fork and run the process
     */
    int run()
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
                    import std.string : fromStringz;

                    stderr.writeln("waitpid: Error: ", strerror(errno).fromStringz);
                }
            }
            while (!WIFEXITED(status) && !WIFSIGNALED(status));

            return WEXITSTATUS(status);
        }
        assert(0);
    }

private:

    int executeChild()
    {
        /* Chroot into working system */
        auto ret = chroot(context.rootfs.toStringz);
        assert(ret == 0);

        /* Drop permissions permanently */
        ret = setgid(requiredUser);
        assert(ret == 0);
        ret = setuid(requiredUser);
        assert(ret == 0);

        auto config = Config.newEnv;
        string[] finalArgs = programName ~ args;

        /* Fakeroot available */
        if (context.fakeroot && context.fakerootBinary != FakerootBinary.None)
        {
            finalArgs = cast(string) context.fakerootBinary ~ finalArgs;
        }

        try
        {
            auto pid = spawnProcess(finalArgs, stdin, stdout, stderr,
                    context.environment, config, "/");
            return wait(pid);
        }
        catch (ProcessException px)
        {
            stderr.writeln("Failed to run container: ", px.message);
            return 1;
        }
    }

    static const uid_t requiredUser = 65534;
}
