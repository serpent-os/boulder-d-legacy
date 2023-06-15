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

import core.stdc.errno : errno;
import core.stdc.stdlib;
import core.stdc.string : strerror;
import core.sys.linux.sched;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd : _exit, fork, pid_t, setgid, setuid, uid_t;
import std.algorithm : filter, joiner, map, splitter;
import std.conv : octal, to;
import std.exception;
import std.experimental.logger;
import std.file : getAttributes;
import std.path : chainPath, pathSeparator;
import std.process;
import std.stdio : stderr, stdin, stdout;
import std.string : format, fromStringz, toStringz;
import std.traits;
import std.typecons;

/**
 * Simplistic encapsulation of a process.
 */
public struct Process
{

    /**
     * Main executable to launch
     */
    string command = null;

    /**
     * Additional arguments to the program
     */
    string[] args = null;

    void setCWD(string cwd)
    {
        this.cwd = cwd;
    }

    void setUID(int uid)
    {
        this.uid = uid.nullable;
    }

    void setGID(int gid)
    {
        this.gid = gid.nullable;
    }

    void setEnvironment(string[string] env)
    {
        this.env = env;
    }

    void withFakeroot(bool fr)
    {
        this.fakeroot = fr;
    }

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

        string[] args;
        if (this.fakeroot)
        {
            auto path = findFakeroot();
            if (path == null)
            {
                throw new Exception("fakeroot requested but no fakeroot executable was found");
            }
            args ~= path;
        }
        args ~= this.command ~ this.args;

        return spawnProcess(args, this.env, Config.newEnv, this.cwd).wait();
    }

    Nullable!int uid;
    Nullable!int gid;
    string cwd;
    string[string] env;
    bool fakeroot;
}

/** isCloneable is a constraint that ensures a callable object returns an integer. */
public template isCloneable(F)
{
    enum isCloneable = isCallable!F && is(ReturnType!F : int);
}

public struct ClonedProcess(F) if (isCloneable!F)
{
    F func;
    int cloneFlags;

    int start()
    {
        if (this.pid > 0)
        {
           throw new Error("cannot clone an already-cloned process");
        }

        immutable auto stackSize = 1024 * 1024;
        this.stack = malloc(stackSize);
        scope(failure)
        {
            free(this.stack);
        }
        auto StackTop = this.stack + stackSize;

        this.waitingPipe = pipe();
        auto args = CloneArguments!F(this.func, this.waitingPipe);
        this.pid = clone(&ClonedProcess._run, StackTop, this.cloneFlags | SIGCHLD, &args);
        if (this.pid < 0)
        {
            throw new ProcessException(format!"failed to clone process: %s"(strerror(errno).fromStringz()));
        }
        return this.pid;
    }

    void goAhead()
    {
        if (pid <= 0)
        {
            throw new Error("cannot make a non-cloned process go ahead");
        }
        this.waitingPipe.writeEnd.close();
    }

    /** join waits for the process to exit and returns the exit status. */
    int join()
    {
        if (pid <= 0)
        {
            throw new Error("cannot join a non-cloned process");
        }

        int status;
        if (waitpid(this.pid, &status, 0) < 0)
        {
            throw new ProcessException(format!"failed to join process: %s"(strerror(errno).fromStringz()));
        }
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

public ClonedProcess!F clonedProcess(F)(F func, int flags) if (isCloneable!F)
{
    return ClonedProcess!F(func, flags);
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

private string findFakeroot()
{
    auto pathFinder = environment.get("PATH", "/usr/bin")
        .splitter(pathSeparator)
        .map!(p => [p.chainPath("fakeroot-sysv"), p.chainPath("fakeroot")])
        .joiner
        .filter!(p => ((p.getAttributes & octal!111) != 0).ifThrown(false));
    return !pathFinder.empty() ? pathFinder.front.to!string : null;
}
