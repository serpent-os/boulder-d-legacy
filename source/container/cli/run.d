/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

module container.cli.run;

import dopt;

@Command() @Help("Run a command in an existing container")
package struct Run
{
    /** Read-only bind mounts */
    @Option() @Long("bind-ro") @Help("Bind a read-only host location into the container")
    string[string] bindMountsRO;

    /** Read-write bind mounts */
    @Option() @Long("bind-rw") @Help("Bind a read-write host location into the container")
    string[string] bindMountsRW;

    /** Toggle networking availability */
    @Option() @Short("n") @Long("network") @Help("Enable network access")
    bool networking = false;

    /** Environmental variables for sub processes */
    @Option() @Short("E") @Long("env") @Help("Set an environmental variable")
    string[string] environment;

    /** UID to use */
    @Option() @Long("root") @Help("Set whether the user inside the container is root")
    root = false;

    /** Immediately start at this directory in the container (cwd) */
    @Option() @Long("workdir") @Help("Start at this working directory in the container (Default: /)")
    string cwd = "/";

    public static void run(Run thiz, string path)
    {

    }
}
