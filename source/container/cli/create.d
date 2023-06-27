/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

module container.cli.create;

import core.sys.posix.unistd : setgid, setuid;
import std.exception : enforce;
import std.file : exists, mkdirRecurse;
import std.path : buildPath;
import std.process : execute;
import std.range : empty;
import std.string : format, toStringz;

import container;
import container.usermapping;
import dopt;

@Command() @Help("Create a new container")
package struct Create
{
    @Option() @Long("moss-path") @Help("Custom moss binary used to populate the container (defaults to \"moss\")")
    string mossPath;

    @Positional() @Required() @Help("Remote repository from where to download packages")
    string repoURL;

    @Positional() @Required() @Help("List of base packages composing the container")
    string[] packages;

    void run(string path)
    {
        this.rootPath = path;
        if (this.mossPath.empty())
        {
            this.mossPath = "moss";
        }
        auto cont = Container();
        cont.withNetworking(true);
        cont.withRootPrivileges(true);
        cont.run([&this.populateContainer]);
    }

private:
    int populateContainer() const
    {
        immutable string localRepo = "/var/cache/boulder/collections/local-x86_64";

        setgid(unprivilegedUGID);
        setuid(unprivilegedUGID);

        enforce(!exists(this.rootPath), format!"directory %s already exists"(this.rootPath));
        mkdirRecurse(this.rootPath);

        execute([this.mossPath, "-D", this.rootPath, "remote", "add", "remote", this.repoURL, "-p", "0"]);
        execute([this.mossPath, "-D", this.rootPath, "install", "-y"] ~ this.packages);

        auto fullLocalRepo = buildPath(this.rootPath, localRepo[1..$]);
        mkdirRecurse(fullLocalRepo);
        execute([this.mossPath, "-D", this.rootPath, "index", fullLocalRepo]);
        execute([this.mossPath, "-D", this.rootPath,
                 "remote", "add", "local-x86_64", "file://" ~ buildPath(localRepo, "stone.index"), "-p", "10"]);

        return 0;
    }

    string rootPath;
}
