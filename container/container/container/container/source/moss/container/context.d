/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Shared Context
 *
 * This module contains the shared context type to ensure reliable
 * sharing of process-wide variables and configuration.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.container.context;

public import moss.container.fakeroot : FakerootBinary;

import core.sys.posix.stdlib : uid_t;
import moss.container.fakeroot : discoverFakeroot;
import std.array : join;
import std.concurrency : initOnce;
import std.experimental.logger;
import std.stdio : stderr;
import std.string : startsWith;

/**
 * Shared singleton instance
 */
private __gshared Context sharedContext = null;

/**
 * Destroy the shared context
 */
static ~this()
{
    if (sharedContext !is null)
    {
        sharedContext.destroy();
        sharedContext = null;
    }
}

/**
 * Return the shared container context
 */
public Context context() @trusted
{
    return initOnce!sharedContext(new Context());
}

/**
 * The Context is shared throughout the codebase as a way
 * of sharing options and providing inspection capability of
 * the target filesystem
 */
public final class Context
{

    /**
     * Update the rootfs directory
     */
    pure @property void rootfs(in string dir) @safe @nogc nothrow
    {
        _rootfs = dir;
    }

    /**
     * Return the rootfs directory
     */
    pure @property const(string) rootfs() @safe @nogc nothrow const
    {
        return _rootfs;
    }

    /**
     * Return location of fakeroot binary
     */
    pure @property FakerootBinary fakerootBinary() @safe @nogc nothrow const
    {
        return _fakerootBinary;
    }

    /**
     * Update whether we want to use fakeroot
     */
    pure @property void fakeroot(bool b) @safe @nogc nothrow
    {
        _fakeroot = b;
    }

    /**
     * Returns true if fakeroot has been requested
     */
    pure @property bool fakeroot() @safe @nogc nothrow const
    {
        return _fakeroot;
    }

    /**
     * Return the working directory used for the process
     */
    pure @property const(string) workDir() @safe @nogc nothrow const
    {
        return cast(const(string)) workDir;
    }

    /**
     * Set the working directory in which to execute the process
     */
    pure @property void workDir(in string newDir) @safe @nogc nothrow
    {
        _workDir = newDir;
    }

    /**
     * Safely join the path onto the rootfs tree
     */
    auto joinPath(in string target) @safe
    {
        return join([rootfs, target.startsWith("/") ? target[1 .. $]: target], "/");
    }

    /**
     * Effective UID
     *
     * Params:
     *      uid = UID for all proceses spawned
     */
    pure @property void effectiveUID(in uid_t uid) @safe @nogc nothrow
    {
        _effectiveUID = uid;
    }

    /**
     * Effective UID
     *
     * Returns: the effective uid set for all processes
     */
    pure @property uid_t effectiveUID() @safe @nogc nothrow
    {
        return _effectiveUID;
    }

    /**
     * Provide environment access
     */
    string[string] environment;

package:

    /**
     * Called by the Container to inspect the root
     */
    bool inspectRoot()
    {
        _fakerootBinary = discoverFakeroot();

        if (_fakerootBinary == FakerootBinary.None && fakeroot)
        {
            error("Fakeroot requested but not available in rootfs, exiting..");
            return false;
        }

        return true;
    }

private:

    /**
     * Only the context() accessor can create a Context.
     */
    this()
    {

    }

    string _rootfs = null;
    FakerootBinary _fakerootBinary = FakerootBinary.None;
    bool _fakeroot = false;
    string _workDir = ".";
    uid_t _effectiveUID;
}
