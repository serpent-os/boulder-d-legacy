module container;

import core.stdc.stdio;
import core.sys.linux.sched;
import core.sys.posix.fcntl;
import core.sys.posix.sys.wait;
import std.conv;
import std.exception;
import std.experimental.logger;
import std.format;
import std.path : dirName;
import std.process : Pipe, environment, pipe, spawnProcess, wait;
import std.string : toStringz, fromStringz;
import std.typecons : Nullable, nullable;

import container.context;
import container.filesystem;
import container.process;
import container.usermapping;

struct Container
{
    this(string overlayRoot, Filesystem fs)
    {
        this.overlayRoot = overlayRoot;
        this.fs = nullable(fs);
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

    int run(T)(int function(T arg)[] funcs)
    {

    }

    int run(Process[] processes)
    {
        auto flags = CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWIPC | CLONE_NEWUSER;
        if (!this.withNet)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }
        auto proc = clonedProcess(&Container.enter, this, flags);
        auto pid = proc.start();
        assert(pid > 0, "clone() failed");
        mapRootUser(pid);
        proc.goAhead();
        return proc.join();
    }

private:
    static int enter(Container thiz)
    {
        if (!thiz.fs.isNull())
        {
            auto fs = thiz.fs.get();
            fs.rootfsDir = mountOverlay(fs.rootfsDir, thiz.overlayRoot);
            fs.mountBase();
            fs.mountProc();
            fs.mountExtra();
            fs.chroot();
        }
        if (thiz.withRoot)
        {
            return thiz.runProcesses();
        }
        auto proc = clonedProcess(&Container.runProcessesUnpriv, thiz, CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWUSER);
        auto pid = proc.start();
        assert(pid > 0, "clone() failed");
        mapHostID(pid, 1000, 1000); // TODO: do not use fixed UID and GID.
        proc.goAhead();
        return proc.join();
    }

    static int runProcessesUnpriv(Container thiz)
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
    Nullable!Filesystem fs;

    bool withNet;
    bool withRoot;
    Process[] processes;
}
