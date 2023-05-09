module moss.container.filesystem;

import std.exception : ErrnoException;
import std.experimental.logger;
import std.format;
import std.file : chdir, exists, isDir, mkdirRecurse, remove, rmdir, symlink, write;
import std.string : toStringz;

import moss.core.mounts;

struct Filesystem
{
    static Filesystem defaultFS(string fakeRootPath, bool withNet)
    {
        FSMount[] baseFS = [
            FSMount("tmpfs", "dev", [
                    "mode": FSConfigValue(FSCONFIG.SET_STRING, cast(void*) "0755".toStringz())
                ]),
            FSMount("tmpfs", "dev/shm"),
            FSMount("tmpfs", "dev/pts"),
            FSMount("tmpfs", "tmp", [
                    "mode": FSConfigValue(FSCONFIG.SET_STRING, cast(void*) "1777".toStringz())
                ]),
        ];
        if (!withNet)
        {
            baseFS ~= FSMount("sysfs", "sys");
        }

        auto baseFiles = [
            FileMount("/dev/null", "dev/null", cast(AT) OPEN_TREE.CLONE),
            FileMount("/dev/zero", "dev/zero", cast(AT) OPEN_TREE.CLONE),
            FileMount("/dev/full", "dev/full", cast(AT) OPEN_TREE.CLONE),
            FileMount("/dev/random", "dev/random", cast(AT) OPEN_TREE.CLONE),
            FileMount("/dev/urandom", "dev/urandom", cast(AT) OPEN_TREE.CLONE),
            FileMount("/dev/tty", "dev/tty", cast(AT) OPEN_TREE.CLONE),
        ];
        if (withNet)
        {
            baseFiles ~= [
                FileMount(
                    "/etc/resolv.conf", "etc/resolv.conf",
                    cast(AT) OPEN_TREE.CLONE, MountAttr(MOUNT_ATTR.RDONLY)),
                FileMount(
                    "/sys", "sys",
                    cast(AT) OPEN_TREE.CLONE, MountAttr(MOUNT_ATTR.RDONLY)),
            ];
        }

        auto baseSymlinks = [
            "/proc/self/fd": "dev/fd",
            "/proc/self/fd/0": "dev/stdin",
            "/proc/self/fd/1": "dev/stdout",
            "/proc/self/fd/2": "dev/stderr",
            "/dev/pts/ptmx": "dev/ptmx",
        ];

        return Filesystem(fakeRootPath, baseFS, baseFiles, baseSymlinks);
    }

    void mountProc()
    {
        auto proc = FSMount("proc", "proc");
        moss.container.filesystem.mountFS(proc, this.fakeRootPath);
    }

    void mountBase()
    {
        auto rootfs = this.rootfsMount();
        moss.container.filesystem.mountFileDir(rootfs, "");
        foreach (m; this.baseFS)
        {
            moss.container.filesystem.mountFS(m, this.fakeRootPath);
        }
        foreach (ref m; this.baseFiles)
        {
            moss.container.filesystem.mountFileDir(m, this.fakeRootPath);
        }
        foreach (source, target; this.baseSymlinks)
        {
            symlink(source, this.fakeRootPath ~ "/" ~ target);
        }
    }

    void mountExtra()
    {
        foreach (ref m; this.extraMounts)
        {
            moss.container.filesystem.mountFileDir(m, this.fakeRootPath);
        }
    }

    void chroot()
    {
        chdir(this.fakeRootPath);
        pivotRoot(".", ".");

        auto unmnt = FileMount("", ".");
        unmnt.unmountFlags = MNT.DETACH;
        unmnt.unmount();
    }

    string fakeRootPath;
    FSMount[] baseFS;
    FileMount[] baseFiles;
    string[string] baseSymlinks;
    FileMount[] extraMounts;

private:
    @property FileMount rootfsMount() const
    {
        return FileMount(
            this.fakeRootPath,
            this.fakeRootPath,
            cast(AT) OPEN_TREE.CLONE);
    }
}

private void mountFS(ref FSMount m, string baseDir)
{
    auto m2 = m;
    m2.target = baseDir ~ "/" ~ m.target;
    m2.target.mkdirRecurse();
    m2.mount();
}

private void mountFileDir(ref FileMount m, string baseDir)
{
    auto m2 = m;
    m2.target = baseDir ~ "/" ~ m.target;
    if (m2.source.isDir())
    {
        m2.target.mkdirRecurse();
    }
    else
    {
        write(m2.target, null);
    }
    m2.mount();
}

private extern (C) long syscall(long number, ...) @system @nogc nothrow;

private void pivotRoot(const string newRoot, const string putOld) @system
{
    immutable int SYS_PIVOT_ROOT = 155;
    const auto ret = syscall(SYS_PIVOT_ROOT, newRoot.toStringz(), putOld.toStringz());
    if (ret < 0)
    {
        throw new ErrnoException("Failed to pivot root");
    }
}
