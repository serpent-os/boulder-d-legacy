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
import std.stdio : stderr;
import std.exception : enforce;

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
     * Run the associated args (cmdline) with various settings in place
     */
    int run() @system
    {
        stderr.writeln("Derp i dunno how to do that, boss");
        return 1;
    }

private:

    string[] _args;
    bool _fakeroot = false;
}
