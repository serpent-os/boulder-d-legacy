module container;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.posix.fcntl;
import core.sys.linux.sched;
import core.sys.posix.sys.wait;
import std.conv;
import std.exception;
import std.experimental.logger;
import std.format;
import std.path : dirName;
import std.process : Pipe, environment, pipe, spawnProcess, wait;
import std.string : toStringz, fromStringz;

import container.context;
import container.filesystem;
import container.mapping;
import container.process;
import moss.core.mounts;

struct Container
{
    this(string overlayRoot, Filesystem fs)
    {
        this.overlayRoot = overlayRoot;
        this.fs = fs;
    }

    void setProcesses(Process[] processes)
    {
        this.processes = processes;
    }

    void withNetworking(bool withNet)
    {
        this.withNet = withNet;
    }

    void withRootPrivileges(bool root)
    {
        this.withRoot = root;
    }

    int run()
    {
        auto flags = CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWIPC | CLONE_NEWUSER;
        if (!this.withNet)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }
        auto proc = ClonedProcess!(Container)(&Container.enter);
        auto pid = proc.start(this, flags);
        assert(pid > 0, "clone() failed");
        mapRootUser(pid);
        proc.goAhead();
        return proc.join();
    }

private:
    extern (C) static int enter(Container thiz)
    {
        thiz.fs.rootfsDir = mountOverlay(thiz.fs.rootfsDir, thiz.overlayRoot);
        thiz.fs.mountBase();
        thiz.fs.mountProc();
        thiz.fs.mountExtra();
        thiz.fs.chroot();
        if (thiz.withRoot)
        {
            return thiz.runProcesses();
        }
        auto proc = ClonedProcess!(Container)(&Container.runProcessesUnpriv);
        auto pid = proc.start(thiz, CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWUSER);
        assert(pid > 0, "clone() failed");
        mapHostID(pid, 1000, 1000); // TODO: do not use fixed UID and GID.
        proc.goAhead();
        return proc.join();
    }

    extern (C) static int runProcessesUnpriv(Container thiz)
    {
        return thiz.runProcesses();
    }

    int runProcesses()
    {
        foreach (ref p; this.processes)
        {
            const auto ret = p.run();
            if (ret < 0)
            {
                return ret;
                // TODO log error. Or maybe the called should do that?
            }
        }
        return 0;
    }

    string overlayRoot;
    Filesystem fs;

    bool withNet;
    bool withRoot;
    Process[] processes;
}

private struct ClonedProcess(T)
{
    extern (C) int function(T arg) func;

    int start(T arg, int flags)
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
        auto args = CloneArguments!(T)(this.func, arg, this.waitingPipe);
        this.pid = clone(&ClonedProcess._run, StackTop, flags | SIGCHLD, &args);
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
        auto args = cast(CloneArguments!(T)*) arg;

        args.waitingPipe.writeEnd.close();
        bool[1] stop;
        args.waitingPipe.readEnd.rawRead(stop);
        if (stop[0])
        {
            return 0;
        }
        return args.userFunc(args.userArg);
    }

    Pipe waitingPipe;
    void* stack;
    int pid;
}

private struct CloneArguments(T)
{
    /** userFunc is the function to be run isolated. */
    extern (C) int function(T arg) userFunc;

    /** userArg is the argument passed to userFunc. */
    T userArg;

    /**
     * waitingPipe puts the cloned process on pause and makes
     * it wait for user's permission to resume.
     */
    Pipe waitingPipe;
}
