/* SPDX-License-Identifier: Zlib */

/**
 * Mount helpers
 *
 * This module should be used for basic mount point management with wrappers
 * around the `mount` and `umount` C API.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */
module moss.container.mounts;

import moss.container.context;
import std.file : exists, mkdirRecurse;
import std.string : toStringz;

/**
 * Set mount specific options
 */
public enum MountOptions
{
    None = 0,
    ReadOnly = 1,
    NoSuid = 2,
    NoDev = 4,
    NoExec = 8,
    Synchronous = 16,
    Remount = 32,
    MandatoryLock = 64,
    DirSync = 128,
    NoAccessTime = 1024,
    NoDirectoryAccessTime = 2048,
    Bind = 4096,
    Move = 8192,
    Rec = 16_384,
    Silent = 32_768,
    PosixACL = 1 << 16,
    Unbindable = 1 << 17,
    Private = 1 << 18,
    Slave = 1 << 19,
    Shared = 1 << 20,
    RelativeAccessTime = 1 << 21,
    KernMount = 1 << 22,
    IVersion = 1 << 23,
    StrictAtime = 1 << 24,
    LazyTime = 1 << 25,
    Active = 1 << 30,
    NoUser = 1 << 31,
}

enum UnmountFlags
{
    Force = 1,
    Detach = 2,
}

/* Bindings to sys/mount.h */
extern (C) int mount(const(char*) specialFile, const(char*) dir,
        const(char*) fstype, ulong rwflag, const void* data);
extern (C) int umount(const(char*) specialFile);
extern (C) int umount2(const(char*) specialFile, int flags);

/**
 * Used to manage system mount points.
 */
public struct MountPoint
{
    string source;
    string fstype = null;
    MountOptions options = MountOptions.None;

    /**
     * Semi sane constructor
     */
    this(in string source, in string fstype, in MountOptions options, in string target)
    {
        this.source = source;
        this.fstype = fstype;
        this.options = options;
        this.target = target;
    }

    /**
     * Try to bring the mountpoint
     */
    bool up()
    {
        if (!realTarget.exists)
        {
            realTarget.mkdirRecurse();
        }

        auto result = mount(source.toStringz, realTarget.toStringz,
                fstype.toStringz, options, null);

        mounted = result == 0 ? true : false;

        if (!mounted)
        {
            return false;
        }

        /* Remount for read-only */
        if ((options & MountOptions.ReadOnly) == MountOptions.ReadOnly)
        {
            auto newOptions = MountOptions.Remount | MountOptions.ReadOnly;
            if ((options & MountOptions.Bind) == MountOptions.Bind)
            {
                newOptions |= MountOptions.Bind;
            }
            result = mount(source.toStringz, realTarget.toStringz,
                    fstype.toStringz, newOptions, null);
        }

        mounted = result == 0 ? true : false;
        return mounted;
    }

    /**
     * Try to teardown the mountpoint. This may take multiple attempts but
     * generally will succeed due to DETACH + FORCE usage.
     */
    bool down()
    {
        import core.thread.osthread : Thread;
        import std.datetime : seconds;

        int attempts = 0;

        if (!mounted)
        {
            return true;
        }

        /* Try 3 times, 1 second apart each time, to get it unmounted */
        while (attempts < 3)
        {
            int ret = 0;
            if (attempts == 0)
            {
                ret = umount2(realTarget.toStringz, UnmountFlags.Force | UnmountFlags.Detach);
            }
            else
            {
                ret = umount(realTarget.toStringz);
            }

            if (ret == 0)
            {
                mounted = false;
                return true;
            }

            Thread.sleep(1.seconds);

            ++attempts;
        }

        return false;
    }

    /**
     * Return the target
     */
    pure @property const(string) target() @safe @nogc nothrow const
    {
        return _target;
    }

    /**
     * Set the target and implicitly set the fully resolved (chroot specific)
     * target to ease use.
     */
    @property void target(in string target) @safe
    {
        _target = target;
        /* Join the localised target to the rootfs, removing / for join to work */
        realTarget = context.joinPath(target);
    }

private:

    string realTarget = null;
    string _target = null;
    bool mounted = false;
}
