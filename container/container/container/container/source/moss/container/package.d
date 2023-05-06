module moss.container;

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

import moss.container.context;
import moss.container.filesystem;
import moss.container.mapping;
import moss.container.process;
import moss.core.mounts;

struct Container
{
    this(Filesystem fs)
    {
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
        auto flags = CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWIPC | CLONE_NEWUSER;
        if (!this.withNet)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }

        auto rootProcess = ClonedProcess!(Container)(&Container.runContainerized);
        auto rootPID = rootProcess.start(this, flags);
        assert(rootPID > 0, "clone() failed");
        mapRootUser(rootPID);
        rootProcess.goAhead();
        return rootProcess.join();
    }

private:
    extern (C) static int runContainerized(Container thiz)
    {
        thiz.mountBase();
        if (thiz.withRoot)
        {
            return executeProcesses(thiz);
        }
        thiz.fs.chroot();
        auto unprivProcess = ClonedProcess!(Container)(&Container.executeProcesses);
        auto unprivPID = unprivProcess.start(thiz, CLONE_NEWUSER);
        assert(unprivPID > 0, "clone() failed");
        mapHostID(unprivPID, 1000, 1000);
        unprivProcess.goAhead();
        return unprivProcess.join();
    }

    extern (C) static int executeProcesses(Container thiz)
    {
        foreach (ref p; thiz.processes)
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

    void mountBase()
    {
        this.fs.mountBase();
    }

    immutable int privilegedUGID = 0;
    immutable int regularUGID = 1;

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
    extern (C) int function(T arg) userFunc;
    T userArg;
    Pipe waitingPipe;
}
