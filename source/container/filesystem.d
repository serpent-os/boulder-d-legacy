module container.filesystem;

import core.sys.posix.unistd : chown;
import std.exception : ErrnoException;
import std.experimental.logger;
import std.format;
import std.file : SpanMode, chdir, dirEntries, exists, isDir, mkdirRecurse, remove, rmdir, symlink, write;
import std.string : toStringz;
import std.path : buildPath;

import moss.core.mounts;

string mountOverlay(string lowerDir, string overlayRoot)
{
    const string upperDir = overlayRoot.buildPath("upper");
    const string workDir = overlayRoot.buildPath("work");
    const string mergedDir = overlayRoot.buildPath("merged");

    foreach (ref path; [upperDir, workDir, mergedDir])
    {
        mkdirRecurse(path);
    }
    auto prop = [
        "lowerdir": FSConfigValue(
            FSCONFIG.SET_STRING,
            cast(void*) lowerDir.toStringz()),
        "upperdir": FSConfigValue(
            FSCONFIG.SET_STRING,
            cast(void*) upperDir.toStringz()),
        "workdir": FSConfigValue(
            FSCONFIG.SET_STRING,
            cast(void*) workDir.toStringz()),
        "volatile": FSConfigValue(FSCONFIG.SET_FLAG, null),
        "userxattr": FSConfigValue(FSCONFIG.SET_FLAG, null),
    ];
    FSMount("overlay", mergedDir, prop).mount();
    return mergedDir;
}

struct Filesystem
{
    static Filesystem defaultFS(string rootfsDir, bool withNet)
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

        return Filesystem(rootfsDir, baseFS, baseFiles, baseSymlinks);
    }

    void mountProc() const
    {
        auto proc = FSMount("proc", "proc");
        container.filesystem.mountFS(proc, this.rootfsDir);
    }

    void mountBase() const
    {
        auto rootfs = this.rootfsMount();
        container.filesystem.mountFileDir(rootfs, "");
        foreach (m; this.baseFS)
        {
            container.filesystem.mountFS(m, this.rootfsDir);
        }
        foreach (ref m; this.baseFiles)
        {
            container.filesystem.mountFileDir(m, this.rootfsDir);
        }
        foreach (source, target; this.baseSymlinks)
        {
            symlink(source, this.rootfsDir.buildPath(target));
        }
    }

    void mountExtra() const
    {
        foreach (ref m; this.extraMounts)
        {
            container.filesystem.mountFileDir(m, this.rootfsDir);
        }
    }

    void chroot() const
    {
        chdir(this.rootfsDir);
        pivotRoot(".", ".");

        auto unmnt = FileMount("", ".");
        unmnt.unmountFlags = MNT.DETACH;
        unmnt.unmount();
    }

    string rootfsDir;

    FSMount[] baseFS;
    FileMount[] baseFiles;
    string[string] baseSymlinks;
    FileMount[] extraMounts;

private:
    @property FileMount rootfsMount() const
    {
        return FileMount(
            this.rootfsDir,
            this.rootfsDir,
            cast(AT) OPEN_TREE.CLONE);
    }
}

private void mountFS(const ref FSMount m, string baseDir) @trusted
{
    auto m2 = cast() m;
    m2.target = baseDir.buildPath(m.target);
    m2.target.mkdirRecurse();
    m2.mount();
}

private void mountFileDir(const ref FileMount m, string baseDir) @trusted
{
    auto m2 = cast() m;
    m2.target = baseDir.buildPath(m.target);
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

private void pivotRoot(string newRoot, string putOld) @system
{
    immutable int SYS_PIVOT_ROOT = 155;
    const auto ret = syscall(SYS_PIVOT_ROOT, newRoot.toStringz(), putOld.toStringz());
    if (ret < 0)
    {
        throw new ErrnoException("Failed to pivot root");
    }
}

private void chownRecursive(int uid, int gid, string path)
{
    foreach (string child; dirEntries(path, SpanMode.shallow, false))
    {
        chown(child.toStringz(), uid, gid);
    }
}
