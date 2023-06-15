/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

module container.cli.run;

import std.algorithm : filter, joiner, map, splitter;
import std.conv : octal, to;
import std.exception : ifThrown;
import std.path : chainPath, pathSeparator;
import std.file : getAttributes;
import std.process : environment;

import container;
import container.filesystem;
import container.process;
import dopt;
import moss.core.mounts;

@Command() @Help("Run a command in an existing container")
package struct Run
{
public:
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
    string[string] environment = null;

    /** UID to use */
    @Option() @Long("root") @Help("Set whether the user inside the container is root")
    root = false;

    @Option() @Short("f") @Long("fakeroot") @Help("Enable fakeroot integration")
    bool fakeroot = false;

    /** Immediately start at this directory in the container (cwd) */
    @Option() @Long("initial-dir") @Help("Start at this working directory in the container (Default: /)")
    string initialDir = "/";

    @Positional() @Help("Parent directory of the OverlayFS working tree")
    string workRoot;

    @Positional() @Help("Command to run, with arguments")
    string[] args;

    void run(string path)
    {
        auto fs = Filesystem.defaultFS(path, this.networking);
        foreach (source, target; bindMountsRO)
        {
            fs.extraMounts ~= FileMount.bindRO(source, target);
        }
        foreach (source, target; bindMountsRW)
        {
            fs.extraMounts ~= FileMount.bindRW(source, target);
        }
        if (this.args.length < 1)
        {
            this.args = ["/bin/bash", "--login"];
        }
        auto cont = Container(this.workRoot, fs);
        cont.withNetworking(this.networking);
        cont.withRootPrivileges(this.root);
        auto proc = this.process();
        proc.setCWD(this.initialDir);
        proc.setEnvironment(this.environment);
        cont.run([proc]);
    }

private:
    Process process()
    {
        Process proc;
        if (this.fakeroot)
        {
            auto path = this.findFakeroot();
            if (path == null)
            {
                throw new Exception("fakeroot requested but no fakeroot executable was found");
            }
            proc = Process(path, this.args);
        }
        else
        {
            proc = Process(this.args[0], this.args.length > 1 ? this.args[1 .. $] : null);
        }
        return proc;
    }

    string findFakeroot()
    {
        auto pathFinder = environment.get("PATH", "/usr/bin")
            .splitter(pathSeparator)
            .map!(p => [p.chainPath("fakeroot-sysv"), p.chainPath("fakeroot")])
            .joiner
            .filter!(p => ((p.getAttributes & octal!111) != 0).ifThrown(false));
        return !pathFinder.empty() ? pathFinder.front.to!string : null;
    }
}
