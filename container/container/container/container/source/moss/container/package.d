module moss.container;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.posix.fcntl;
import core.sys.linux.sched;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd : close, geteuid, getegid, write;
import std.conv;
import std.exception;
import std.experimental.logger;
import std.format;
import std.path : dirName;
import std.process : Pipe, environment, pipe, spawnProcess, wait;
import std.string : toStringz, fromStringz;
import std.typecons;

import moss.container.context;
import moss.container.filesystem;
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
        this.mapHostUser(rootPID);
        rootProcess.goAhead();
        return rootProcess.join();
    }

private:
    extern (C) static int runContainerized(Container thiz)
    {
        thiz.mount();
        scope (exit)
        {
            thiz.unmount();
        }

        if (!thiz.withRoot)
        {
            dropPrivileges(1000, 1000);
        }

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

    void mapHostUser(int pid)
    {
        auto uids = [IDMap(privilegedUGID, geteuid(), 1)];
        auto gids = [IDMap(privilegedUGID, getegid(), 1)];

        auto sub = subID();
        sub[0].inner = regularUGID;
        uids ~= sub[0];
        sub[1].inner = regularUGID;
        gids ~= sub[1];

        mapUser(pid, uids, gids);
    }

    int mount()
    {
        auto ret = this.fs.mountBase();
        if (ret < 0)
        {
            return ret;
        }
        if (this.withNet)
        {
            ret = this.fs.mountResolvConf();
            if (ret < 0)
            {
                return ret;
            }
        }
        return this.fs.mountExtra();
    }

    void unmount() const
    {
        this.fs.unmountExtra();
        this.fs.unmountBase();
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

private struct IDMap
{
    int inner;
    int outer;
    int length;

    string toString() const pure @safe
    {
        return format!"%s %s %s"(this.inner, this.outer, this.length);
    }
}

private int mapUser(int pid, IDMap[] uids, IDMap[] gids)
{
    /* We could write the uid_map and gid_map files ourselves
     * if we wanted to run containerized processes only as root.
     * But since we want to be able to drop privileges by setting
     * a different UID and GID, we require *two* associations.
     * This is impossible without CAP_SETUID capability. `newuidmap`
     * has it, so we'll use it.
     * See https://man7.org/linux/man-pages/man7/user_namespaces.7.html
     * at chapter "Defining user and group ID mappings: writing to uid_map and gid_map".
     */

    const auto pidString = to!string(pid);
    string[] mapsToArgs(IDMap[] maps)
    {
        string[] args;
        foreach (ref map; maps)
        {
            args ~= [
                to!string(map.inner), to!string(map.outer),
                to!string(map.length)
            ];
        }
        return args;
    }

    int status;
    status = spawnProcess("newuidmap" ~ (pidString ~ mapsToArgs(uids))).wait();
    if (status < 0)
    {
        return status;
    }
    status = spawnProcess("newgidmap" ~ (pidString ~ mapsToArgs(gids))).wait();

    return status;
}

private extern (C)
{
    bool subid_init(const char* progname, FILE* logfd);
    struct subid_range
    {
        ulong start;
        ulong count;
    }

    int subid_get_uid_ranges(const char* owner, subid_range** ranges);
    int subid_get_gid_ranges(const char* owner, subid_range** ranges);
}

private Tuple!(IDMap, IDMap) subID()
{
    auto user = environment.get("USER");
    assert(user != "", "USER environment variable is not defined");

    /* There may be multiple rages. We just need one, so consider the first. */
    subid_range* uid;
    subid_range* gid;
    int ret;
    subid_init(null, null);
    ret = subid_get_uid_ranges(user.toStringz(), &uid);
    assert(ret > 0, "Failed to get UID range, or no ranges available");
    ret = subid_get_gid_ranges(user.toStringz(), &gid);
    assert(ret > 0, "Failed to get GID range, or no ranges available");

    return tuple(IDMap(0, cast(int) uid.start, cast(int) uid.count), IDMap(0, cast(int) gid.start, cast(
            int) gid.count));
}

private void dropPrivileges(int outerUID, int outerGID)
{
    unshare(CLONE_NEWUSER);

    Tuple!(string, string)[] mapping = [
        tuple("/proc/self/uid_map", format!"%s 0 1"(outerUID)),
        tuple("/proc/self/setgroups", "deny"),
        tuple("/proc/self/gid_map", format!"%s 0 1"(outerGID)),
    ];

    foreach (ref entry; mapping)
    {
        auto fd = open(entry[0].toStringz(), O_WRONLY);
        assert(fd > 0, format!"Failed to open %s"(entry[0]));
        scope (exit)
        {
            close(fd);
        }
        const auto ret = write(fd, entry[1].ptr, entry[1].length);
        assert(ret > 0, format!"Failed to write into %s"(entry[0]));
    }
}
