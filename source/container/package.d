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

    void withNetworking(bool withNet)
    {
        this.withNet = withNet;
    }

    void withRootPrivileges(bool root)
    {
        this.withRoot = root;
    }

    int run(F)(const F[] funcs) if (isCloneable!F)
    {
        this.runnable = () {
            foreach (f; funcs)
            {
                const auto ret = f();
                if (ret != 0)
                {
                    return ret;
                }
            }
            return 0;
        };
        return this._run();
    }

    int run(const Process[] processes)
    {
        this.runnable = () {
            foreach (ref p; processes)
            {
                const auto ret = p.run();
                if (ret < 0)
                {
                    return ret;
                }
            }
            return 0;
        };
        return this._run();
    }

private:
    int _run() const
    {
        auto flags = CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWIPC | CLONE_NEWUSER;
        if (!this.withNet)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }
        auto proc = ClonedProcess!(int delegate())(&this.enter, flags);
        auto pid = proc.start();
        assert(pid > 0, "clone() failed");
        mapRootUser(pid);
        proc.goAhead();
        return proc.join();
    }

    int enter() const @trusted
    {
        if (!this.fs.isNull())
        {
            auto fs = cast() this.fs.get();
            fs.rootfsDir = mountOverlay(fs.rootfsDir, this.overlayRoot);
            fs.mountBase();
            fs.mountProc();
            fs.mountExtra();
            fs.chroot();
        }
        if (this.withRoot)
        {
            return this.runnable();
        }
        auto proc = ClonedProcess!(int delegate())(this.runnable, CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWUSER);
        auto pid = proc.start();
        assert(pid > 0, "clone() failed");
        mapHostID(pid, 1000, 1000); // TODO: do not use fixed UID and GID.
        proc.goAhead();
        return proc.join();
    }

    string overlayRoot;
    Nullable!Filesystem fs;

    bool withNet;
    bool withRoot;

    int delegate() runnable;
}
