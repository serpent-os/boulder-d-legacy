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

/**
 * Bitwise mount type
 */
public enum MountType
{
    Bind = 1 << 0,
    ReadOnly = 1 << 1,
    TemporaryFilesystem = 1 << 2,
}

/**
 * Making mounts available to nspawn
 */
public struct SpawnMount
{
    string source = null;
    string target = null;
    MountType type = MountType.Bind;
}

/**
 * Alter the console mode of nspawn
 */
public enum ConsoleMode : string
{
    Interactive = "interactive",
    ReadOnly = "read-only",
    Passive = "passive",
    Pipe = "pipe",
    AutoPipe = "autopipe",
}

/**
 * Most direct commands should run as Pid2 to ensure they have help in
 * running and shutting down. Interactive shells should usually run as
 * pid1 to alleviate fork issues.
 *
 * Lastly, "Boot" to actually boot it.
 */
public enum RunBehaviour
{
    Pid1,
    Pid2,
    Boot,
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

    bool hostRegistered = true;

    /**
     * The default run behaviour is as Pid2
     */
    RunBehaviour runBehaviour = RunBehaviour.Pid2;

    ConsoleMode consoleMode = ConsoleMode.ReadOnly;

    SpawnMount[] mounts;

    /**
     * Request execution for this spawner and await completion
     */
    SpawnReturn run(in string rootfs, in string[] command)
    {
        static immutable string toolPath = "/usr/bin/systemd-nspawn";
        string[] spawnFlags;
        spawnFlags ~= format!"--register=%s"(hostRegistered ? "yes" : "no");

        if (privateNetwork)
        {
            spawnFlags ~= "--private-network";
        }

        /* Establish run behaviour */
        final switch (runBehaviour)
        {
        case RunBehaviour.Boot:
            spawnFlags ~= "--boot";
            break;
        case RunBehaviour.Pid2:
            spawnFlags ~= "--as-pid2";
            break;
        case RunBehaviour.Pid1:
            /* Do nothing, default */
            break;
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

        spawnFlags ~= format!"--console=%s"(cast(string) consoleMode);

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
    auto command = ["/bin/bash", "--login"];
    s.runBehaviour = RunBehaviour.Pid1;
    s.consoleMode = ConsoleMode.Interactive;
    s.run("/home/ikey/serpent/moss/destdir", command)
        .match!((err) => assert(0 == 1, err.errorString), (bool b) {});
}
