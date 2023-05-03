module moss.container.filesystem;

import std.experimental.logger;
import std.format;
import std.file : chdir, exists, mkdirRecurse, remove, rmdir, symlink, write;
import std.string : toStringz;

import moss.core.mounts;

struct Filesystem
{
    static Filesystem defaultFS(string fakeRootPath)
    {
        auto tmp = Mount("", "tmp", "tmpfs", MS.NONE,
            mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV).nullable);
        tmp.setData("mode=1777".toStringz());
        auto baseDirs = [
            Mount("", "proc", "proc", MS.NONE,
                mount_attr(
                    MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV | MOUNT_ATTR.NOEXEC | MOUNT_ATTR
                    .RELATIME).nullable),
            Mount("/sys", "sys", "", MS.BIND | MS.REC,
                mount_attr(MOUNT_ATTR.RDONLY).nullable, MNT.DETACH),
            tmp,
            Mount("", "dev", "tmpfs", MS.NONE,
                mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NOEXEC).nullable),
            Mount("", "dev/shm", "tmpfs", MS.NONE,
                mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NODEV).nullable),
            Mount("", "dev/pts", "devpts", MS.NONE,
                mount_attr(MOUNT_ATTR.NOSUID | MOUNT_ATTR.NOEXEC | MOUNT_ATTR.RELATIME).nullable),
        ];

        auto baseSymlinks = [
            "/proc/self/fd": "dev/fd",
            "/proc/self/fd/0": "dev/stdin",
            "/proc/self/fd/1": "dev/stdout",
            "/proc/self/fd/2": "dev/stderr",
            "/dev/pts/ptmx": "dev/ptmx",
        ];

        auto baseFiles = [
            Mount("/dev/null", "dev/null", "", MS.BIND),
            Mount("/dev/zero", "dev/zero", "", MS.BIND),
            Mount("/dev/full", "dev/full", "", MS.BIND),
            Mount("/dev/random", "dev/random", "", MS.BIND),
            Mount("/dev/urandom", "dev/urandom", "", MS.BIND),
            Mount("/dev/tty", "dev/tty", "", MS.BIND),
        ];

        return Filesystem(fakeRootPath, baseDirs, baseSymlinks, baseFiles);
    }

    int mountBase()
    {
        auto rootfs = this.rootfsMount();
        auto ret = moss.container.filesystem.mount(rootfs, "", true);
        if (ret < 0)
        {
            return ret;
        }
        foreach (m; this.baseDirs)
        {
            ret = moss.container.filesystem.mount(m, this.fakeRootPath, true);
            if (ret < 0)
            {
                return ret;
            }
        }
        foreach (source, target; this.baseSymlinks)
        {
            symlink(source, this.fakeRootPath ~ "/" ~ target);
        }
        foreach (ref m; this.baseFiles)
        {
            ret = moss.container.filesystem.mount(m, this.fakeRootPath, false);
            if (ret < 0)
            {
                return ret;
            }
        }
        return 0;
    }

    int mountResolvConf()
    {
        info("Installing /etc/resolv.conf for networking");
        auto m = this.resolvConf();
        if (m.target.exists)
        {
            return 0;
        }
        return moss.container.filesystem.mount(m, this.fakeRootPath, false);
    }

    int mountExtra()
    {
        foreach (ref m; this.extraMounts)
        {
            auto ret = moss.container.filesystem.mount(m, this.fakeRootPath, true);
            if (ret < 0)
            {
                return ret;
            }
        }
        return 0;
    }

    int chroot()
    {
        chdir(this.fakeRootPath);
        auto ret = pivotRoot(".", ".");
        if (ret < 0)
        {
            return ret;
        }

        auto unmnt = Mount("", ".");
        unmnt.unmountFlags = MNT.DETACH;
        auto err = unmnt.unmount();
        if (!err.isNull())
        {
            error(format!"Failed to bring down mountpoint: %s, %s"(unmnt.target, err.get.toString));
            return -1;
        }
        return 0;
    }

    string fakeRootPath;

    Mount[] baseDirs;
    string[string] baseSymlinks;
    Mount[] baseFiles;

    Mount[] extraMounts;

private:
    static @property Mount resolvConf()
    {
        return Mount(
            "/etc/resolv.conf",
            "etc/resolv.conf",
            "",
            MS.BIND,
            mount_attr(MOUNT_ATTR.RDONLY).nullable);
    }

    @property Mount rootfsMount() const
    {
        return Mount(
            this.fakeRootPath,
            this.fakeRootPath,
            "",
            MS.BIND);
    }
}

private int mount(ref Mount m, string baseDir, bool isDir)
{
    auto m2 = m;
    m2.target = baseDir ~ "/" ~ m.target;

    if (isDir)
    {
        m2.target.mkdirRecurse();
    }
    else
    {
        write(m2.target, null);
    }
    auto err = m2.mount();
    if (!err.isNull)
    {
        error(format!"Failed to activate mountpoint: %s, %s"(m2.target, err.get.toString));
        return 1;
    }
    return 0;
}

private int unmount(const ref Mount m, string baseDir, bool isDir)
{
    auto m2 = cast(Mount) m;
    m2.target = baseDir ~ "/" ~ m.target;

    auto err = m2.unmount();
    if (!err.isNull())
    {
        error(format!"Failed to bring down mountpoint: %s, %s"(m2.target, err.get.toString));
        return -1;
    }
    if (isDir)
    {
        rmdir(m2.target);
    }
    else
    {
        remove(m2.target);
    }
    return 0;
}

private extern (C) long syscall(long number, ...) @system @nogc nothrow;

private int pivotRoot(const string newRoot, const string putOld) @system nothrow
{
    immutable int SYS_PIVOT_ROOT = 155;
    return cast(int) syscall(SYS_PIVOT_ROOT, newRoot.toStringz(), putOld.toStringz());
}
