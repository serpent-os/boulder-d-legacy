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
import std.process;

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

public enum MountType
{
    Bind = 1 << 0,
    ReadOnly = 1 << 1,
    TemporaryFilesystem = 1 << 2,
}

public struct SpawnMount
{
    string source = null;
    string target = null;
    MountType type = MountType.Bind;
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

    SpawnMount[] mounts;

    /**
     * Request execution for this spawner and await completion
     */
    SpawnReturn run(in string rootfs, in string[] command)
    {
        static immutable string toolPath = "/usr/bin/systemd-nspawn";
        string[] spawnFlags;
        spawnFlags ~= boot ? "--boot" : "--as-pid2";
        spawnFlags ~= format!"--register=%s"(hostRegistered ? "yes" : "no");

        if (privateNetwork)
        {
            spawnFlags ~= "--private-network";
        }

        foreach (m; mounts)
        {
            if ((m.type & MountType.TemporaryFilesystem) == MountType.TemporaryFilesystem)
            {
                assert(m.target !is null);
                spawnFlags ~= format!"--tmpfs=%s"(m.target);
            }
            else if ((m.type & MountType.Bind) == MountType.Bind)
            {
                const auto readOnly = (m.type & MountType.ReadOnly) == MountType.ReadOnly;
                if (readOnly)
                {
                    spawnFlags ~= format!"--bind-ro=%s:%s"(m.source, m.target);
                }
                else
                {
                    spawnFlags ~= format!"--bind=%s:%s"(m.source, m.target);
                }
            }
            else
            {
                assert(0 == 1, "oh god you didnt");
            }
        }

        /**
         * Finally set the root
         */
        spawnFlags ~= ["-D", rootfs];
        spawnFlags ~= command;

        import std.stdio : writeln;

        writeln(toolPath, " ", spawnFlags);

        auto cmd = execute(toolPath ~ spawnFlags);
        auto ret = cmd.status;

        if (ret != 0)
        {
            return SpawnReturn(SpawnError(ret, cmd.output));
        }

        writeln(cmd.output);
        return SpawnReturn(true);
    }
}

@("Super simple unit test during development")
unittest
{
    Spawner s;
    s.privateNetwork = true;
    auto command = ["/bin/ls", "-la"];
    s.run("/home/ikey/serpent/moss/destdir", command)
        .match!((err) => assert(0 == 1, err.errorString), (bool b) {});
}
