/*
 * This file is part of moss-container.
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

module moss.container.process;

import core.sys.posix.unistd : setuid, setgid, fork, pid_t, uid_t, _exit;
import core.sys.posix.sys.wait;
import std.string : toStringz;

/**
 * Chroot to another root filesystem
 */
extern (C) int chroot(const(char*) dir);

/**
 * Simplistic encapsulation of a process.
 */
public struct Process
{

    /**
     * Main executable to launch
     */
    string programName = null;

    /**
     * Additional arguments to the program
     */
    string[] args = null;

package:

    /**
     * Fork and run the process
     */
    int run(in string rootfs, in string[string] environment)
    {
        pid_t child = fork();
        int status = 0;

        /* We're the fork */
        if (child == 0)
        {
            _exit(executeChild(rootfs, environment));
        }
        else
        {
            do
            {
                status = waitpid(child, &status, WCONTINUED);
            }
            while (!WIFEXITED(status) && !WIFSIGNALED(status));

            return status;
        }
        assert(0);
    }

private:

    int executeChild(in string rootfs, in string[string] environment)
    {
        /* Chroot into working system */
        auto ret = chroot(rootfs.toStringz);
        assert(ret == 0);

        /* Drop permissions permanently */
        ret = setgid(requiredUser);
        assert(ret == 0);
        ret = setuid(requiredUser);
        assert(ret == 0);

        return 0;
    }

    static const uid_t requiredUser = 65534;
}
