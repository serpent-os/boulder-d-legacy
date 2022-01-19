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

module moss.container;

public import moss.container.mounts;
public import moss.container.process;
public import moss.container.slist;

import core.sys.linux.sched;

/**
 * The Container type is used for managing the lifecycle of multiple processes,
 * chiefly the "main" process
 */
public struct Container
{
    @disable this();

    /**
     * Require initialisation with a valid rootfs location
     */
    this(in string rootfs)
    {
        this.rootfs = rootfs;
    }

    /**
     * Run the containers workload and processes
     */
    int run()
    {
        bringupNamespace();
        return 0;
    }

    /**
     * Add a new mountpoint.
     */
    void addMount(Mount mountpoint)
    {
        mountPoints.append(mountpoint);
    }

    /**
     * Append a process for execution
     */
    void addProcess(Process p)
    {
        processes.append(p);
    }

    /**
     * Enable or disable networking accessibility
     */
    bool networking = false;

private:

    /**
     * Enter a new namespace by unsharing the execution context namespace
     */
    void bringupNamespace()
    {
        auto flags = CLONE_NEWPID | CLONE_NEWNS;
        if (!networking)
        {
            flags |= CLONE_NEWNET | CLONE_NEWUTS;
        }
        auto ret = unshare(flags);
        assert(ret == 0);
    }

    /**
     * Construct the special requirements of our /dev filesystem
     */
    void constructDevfs()
    {

    }

    /**
     * Bring up new mounts
     */
    void bringupMounts()
    {

    }

    /**
     * Tear down the mounts in use
     */
    void teardownMounts()
    {

    }

    SList!Mount mountPoints;
    SList!Process processes;
    string rootfs = null;
}
