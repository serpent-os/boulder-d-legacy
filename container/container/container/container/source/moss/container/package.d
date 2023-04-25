module moss.container;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.linux.sched;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd : geteuid, getegid;
import std.conv;
import std.exception;
import std.experimental.logger;
import std.file : copy, exists, mkdirRecurse, remove, rmdir, symlink, write;
import std.format;
import std.path : dirName;
import std.process : Pipe, environment, pipe, spawnProcess, wait;
import std.string : toStringz;
import std.typecons;

import moss.core.mounts;
import moss.container.context;
import moss.container.process;

Mount[] defaultDirMounts()
{
    auto dev = Mount("", context.joinPath("/dev"), "tmpfs", MS.NONE,
        mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NOEXEC).nullable);
    dev.setData("mode=1777".toStringz());

    return [
        Mount("", context.joinPath("/proc"), "proc", MS.NONE,
            mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV | MOUNT_ATTR.NOEXEC | MOUNT_ATTR
                .RELATIME).nullable),
        Mount("/sys", context.joinPath("/sys"), "", MS.BIND | MS.REC,
            mount_attr(MOUNT_ATTR.RDONLY).nullable, MNT.DETACH),
        Mount("", context.joinPath("/tmp"), "tmpfs", MS.NONE,
            mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV).nullable),
        dev,
        Mount("", context.joinPath("/dev/shm"), "tmpfs", MS.NONE,
            mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV).nullable),
        Mount("", context.joinPath("/dev/pts"), "devpts", MS.NONE,
            mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NOEXEC | MOUNT_ATTR.RELATIME).nullable),
    ];
}

string[string] defaultSymlinks()
{
    return [
        "/proc/self/fd": context.joinPath("/dev/fd"),
        "/proc/self/fd/0": context.joinPath("/dev/stdin"),
        "/proc/self/fd/1": context.joinPath("/dev/stdout"),
        "/proc/self/fd/2": context.joinPath("/dev/stderr"),
        "pts/ptmx": context.joinPath("/dev/ptmx"),
    ];
}

Mount[] defaultNodeMounts()
{
    return [
        Mount("/dev/null", context.joinPath("/dev/null"), "", MS.BIND),
        Mount("/dev/zero", context.joinPath("/dev/zero"), "", MS.BIND),
        Mount("/dev/full", context.joinPath("/dev/full"), "", MS.BIND),
        Mount("/dev/random", context.joinPath("/dev/random"), "", MS.BIND),
        Mount("/dev/urandom", context.joinPath("/dev/urandom"), "",
            MS.BIND),
        Mount("/dev/tty", context.joinPath("/dev/tty"), "", MS.BIND),
    ];
}

struct IDMap
{
    int inner;
    int outer;
    int length;

    string toString() const pure @safe
    {
        return format!"%s %s %s"(this.inner, this.outer, this.length);
    }
}

struct ChildArguments
{
    Container container;
    Pipe waitingPipe;
    int ugid; /* UID and GID are equal. */
}

struct Container
{
    void setDirMounts(Mount[] mounts)
    {
        this.dirMounts = mounts;
    }

    void setSymlinks(string[string] links)
    {
        this.symlinks = links;
    }

    void setNodeMounts(Mount[] mounts)
    {
        this.nodeMounts = mounts;
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

        auto waitingPipe = pipe();
        auto args = ChildArguments(
            this,
            waitingPipe,
            this.withRoot ? privilegedUGID : regularUGID,
        );

        immutable auto stackSize = 1024 * 1024;
        auto stack = malloc(stackSize);
        scope (exit)
        {
            free(stack);
        }
        auto StackTop = stack + stackSize;
        auto pid = clone(&runContainerized, StackTop, flags | SIGCHLD, &args);
        assert(pid > 0, "clone did not clone...");

        this.mapHostUser(pid);
        waitingPipe.writeEnd.close();

        int status;
        const auto ret = waitpid(pid, &status, 0);
        enforce(ret >= 0);
        return WEXITSTATUS(status);
    }

private:
    extern (C) static int runContainerized(void* arg)
    {
        auto args = cast(ChildArguments*) arg;

        args.waitingPipe.writeEnd.close();
        bool[1] stop;
        args.waitingPipe.readEnd.rawRead(stop);

        if (stop[0])
        {
            return 0;
        }

        args.container.mount();
        scope (exit)
        {
            args.container.unmount();
        }
        foreach (ref p; args.container.processes)
        {
            p.setUID(args.ugid);
            p.setGID(args.ugid);
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
        foreach (m; this.dirMounts)
        {
            m.target.mkdirRecurse();
            auto err = m.mount();
            if (!err.isNull)
            {
                error(format!"Failed to activate mountpoint: %s, %s"(m.target, err.get.toString));
                return 1;
            }
        }
        foreach (source, target; this.symlinks)
        {
            symlink(source, target);
        }
        foreach (ref m; this.nodeMounts)
        {
            write(m.target, null);
            auto err = m.mount();
            if (!err.isNull)
            {
                error(format!"Failed to activate mountpoint: %s, %s"(m.target, err.get.toString));
                return 1;
            }
        }
        if (this.withNet && !this.resolvConf.target.exists)
        {
            info("Installing /etc/resolv.conf for networking");
            write(this.resolvConf.target, null);
            auto err = this.resolvConf.mount();
            if (!err.isNull)
            {
                error(format!"Failed to activate mountpoint: %s, %s"(this.resolvConf.target, err
                        .get.toString));
                return 1;
            }
        }
        return 0;
    }

    void unmount() const
    {
        auto err = this.resolvConf.unmount();
        if (err.isNull)
        {
            remove(this.resolvConf.target);
        }
        foreach_reverse (ref m; this.nodeMounts)
        {
            err = m.unmount();
            if (!err.isNull())
            {
                error(format!"Failed to bring down mountpoint: %s, %s"(m, err.get.toString));
                continue;
            }
            remove(m.target);
        }
        foreach (source, target; this.symlinks)
        {
            remove(target);
        }
        foreach_reverse (ref m; this.dirMounts)
        {
            err = m.unmount();
            if (!err.isNull())
            {
                error(format!"Failed to bring down mountpoint: %s, %s"(m, err.get.toString));
                continue;
            }
            rmdir(m.target);
        }
    }

    static @property Mount resolvConf()
    {
        return Mount(
            "/etc/resolv.conf",
            context.joinPath(
                "/etc/resolv.conf"),
            "",
            MS.BIND,
            mount_attr(MOUNT_ATTR.RDONLY).nullable);
    }

    immutable int privilegedUGID = 0;
    immutable int regularUGID = 1;

    Mount[] dirMounts;
    string[string] symlinks;
    Mount[] nodeMounts;
    bool withNet;
    bool withRoot;

    Process[] processes;
}

int mapUser(int pid, IDMap[] uids, IDMap[] gids)
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
                to!string(map.inner), to!string(map.outer), to!string(map.length)
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

extern (C)
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

Tuple!(IDMap, IDMap) subID()
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
