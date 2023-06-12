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
module container.process;

import core.stdc.stdlib;
import core.sys.linux.sched;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd : _exit, fork, pid_t, setgid, setuid, uid_t;
import std.exception;
import std.experimental.logger;
import std.process;
import std.stdio : stderr, stdin, stdout;
import std.string : format, fromStringz, toStringz;
import std.traits;
import std.typecons;

import container.context;

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
        int ret;
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

public ClonedProcess!F clonedProcess(F)(F func, int flags) if (isCloneable!F)
{
    return ClonedProcess!F(func, flags);
}

public struct ClonedProcess(F) if (isCloneable!F)
{
    F func;
    int cloneFlags;

    int start()
    {
        if (pid != 0)
        {
            return -1;
        }

        immutable auto stackSize = 1024 * 1024;
        this.stack = malloc(stackSize);
        // TODO: free stack if clone() failed.
        auto StackTop = this.stack + stackSize;

        this.waitingPipe = pipe();
        auto args = CloneArguments!(F, T)(this.func, this.args, this.waitingPipe);
        this.pid = clone(&ClonedProcess._run, StackTop, this.cloneFlags | SIGCHLD, &args);
        return this.pid;
    }

    void goAhead()
    {
        if (pid == 0)
        {
            return;
        }
        this.waitingPipe.writeEnd.close();
    }

    int join()
    {
        if (pid == 0)
        {
            return 0;
        }

        int status;
        const auto ret = waitpid(this.pid, &status, 0);
        enforce(ret >= 0);

        this.pid = 0;
        free(this.stack);

        return WEXITSTATUS(status);
    }

private:
    extern (C) static int _run(void* arg)
    {
        auto args = cast(CloneArguments!(F)*) arg;

        args.waitingPipe.writeEnd.close();
        bool[1] stop;
        args.waitingPipe.readEnd.rawRead(stop);
        if (stop[0])
        {
            return 0;
        }
        return args.func();
    }

    Pipe waitingPipe;
    void* stack;
    int pid;
}

private struct CloneArguments(F) if (isCloneable!F)
{
    /** func is the the callable object to be run isolated. */
    F func;

    /**
     * waitingPipe puts the cloned process on pause and makes
     * it wait for user's permission to resume.
     */
    Pipe waitingPipe;
}

/** isCloneable is a constraint that ensures a callable object returns an integer. */
private template isCloneable(F)
{
    enum isCloneable = isCallable!F && is(ReturnType!F : int);
}
