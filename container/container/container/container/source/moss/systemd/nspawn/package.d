/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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

module moss.systemd.nspawn;

import std.sumtype;
import std.string : format;

/**
 * The Spawner execute function's return type
 */
alias SpawnReturn = SumType!(bool, SpawnError);

/**
 * SpawnError is yielded (stack local) when we fail to run systemd-nspawn for
 * some reason (likely permissions or kernel)
 */
struct SpawnError
{

    /**
     * Tool exit code
     */
    int exitCode;

    /**
     * Error string encountered
     */
    string errorString;

    /**
     * Return string representation of the error
     */
    const(string) toString() const
    {
        return errorString;
    }
}

/**
 * The Spawner can invoke systemd-nspawn with the correct flags to
 * vastly simplify utilisation
 */
public struct Spawner
{

    /** Enable this if you need to disable host network access */
    bool privateNetwork = false;

    bool readOnlyFilesystem = false;

    bool boot = false;

    bool hostRegistered = true;

    /**
     * Request execution for this spawner and await completion
     */
    SpawnReturn execute(string rootfs)
    {
        static immutable string toolPath = "/usr/bin/systemd-nspawn";
        string[] spawnFlags;
        spawnFlags ~= boot ? "--boot" : "--as-pid2";
        spawnFlags ~= format!"--host-registered=%s"(hostRegistered ? "yes" : "no");

        if (privateNetwork)
        {
            spawnFlags ~= "--private-network";
        }

        /**
         * Finally set the root
         */
        spawnFlags ~= ["-D", rootfs];

        import std.stdio : writeln;

        writeln(toolPath, " ", spawnFlags);

        return SpawnReturn(SpawnError(-1, "Not yet implemented"));
    }
}

@("Super simple unit test during development")
unittest
{
    Spawner s;
    s.privateNetwork = true;
    s.execute("/home/ikey/serpent/moss/destdir").match!((err) => assert(0 == 1,
            err.errorString), (bool b) {});
}
