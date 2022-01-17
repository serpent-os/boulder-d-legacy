/*
 * This file is part of moss-config.
 *
 * Copyright © 2020-2022 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.container;
import std.stdio : stderr, stdin, stdout;
import std.exception : enforce;
import std.process;
import std.file : exists;
import std.string : empty;

enum FakerootBinary : string
{
    Sysv = "/usr/bin/fakeroot-sysv",
    Default = "/usr/bin/fakeroot"
}

/**
 * A Container is used for the purpose of isolating newly launched processes.
 */
public final class Container
{
    @disable this();

    /**
     * Create a new Container instance with the given args
     */
    this(in string[] argv)
    {
        enforce(argv.length > 0);
        _args = cast(string[]) argv;

        /* Find the correct fakeroot */
        foreach (searchpath; [FakerootBinary.Sysv, FakerootBinary.Default])
        {
            if (searchpath.exists)
            {
                fakerootBinary = searchpath;
                break;
            }
        }

        enforce(fakerootBinary.exists, "Cannot run without fakeroot helper");
    }

    /**
     * Return the arguments (CLI args) that we intend to dispatch
     */
    pure @property const(string)[] args() @safe @nogc nothrow const
    {
        return cast(const(string)[]) _args;
    }

    /**
     * Returns true if fakeroot will be used
     */
    pure @property bool fakeroot() @safe @nogc nothrow const
    {
        return _fakeroot;
    }

    /**
     * Enable or disable the use of fakeroot
     */
    pure @property void fakeroot(bool b) @safe @nogc nothrow
    {
        _fakeroot = b;
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
     * Return the chroot directory we intend to use
     */
    pure @property const(string) chrootDir() @safe @nogc nothrow const
    {
        return cast(const(string)) _chrootDir;
    }

    /**
     * Update the chroot directory
     */
    pure @property void chrootDir(in string d) @safe @nogc nothrow
    {
        _chrootDir = d;
    }

    /**
     * Access the environment property
     */
    pragma(inline, true) pure @property inout(string[string]) environment() @safe @nogc nothrow inout
    {
        return _environ;
    }

    /**
     * Run the associated args (cmdline) with various settings in place
     */
    int run() @system
    {
        enforce(!_chrootDir.empty, "Cannot run without a valid chroot directory");

        auto config = Config.newEnv;
        string[] finalArgs = _args;
        if (fakeroot)
        {
            finalArgs = cast(string) fakerootBinary ~ finalArgs;
        }
        stdout.writefln("finalArgs: %s", finalArgs);
        auto pid = spawnProcess(finalArgs, stdin, stdout, stderr, _environ, config, _workDir);
        auto statusCode = wait(pid);
        return statusCode;
    }

private:

    string[] _args;
    bool _fakeroot = false;
    string _workDir = ".";
    string[string] _environ = null;
    string _chrootDir = null;
    FakerootBinary fakerootBinary = FakerootBinary.Sysv;
}
