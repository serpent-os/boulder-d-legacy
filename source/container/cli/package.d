/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

module container.cli;

import std : stderr, stdout;
import std.range;
import std.sumtype;

import container.cli.create;
import container.cli.remove;
import container.cli.run;
import dopt;

alias Subcommands = SumType!(Create, Remove, Run);

@Command("container")
@Help(`Use container to manage lightweight containers using Linux namespaces.
container sits between boulder and mason to provide isolation
support, however you can also use container for smoketesting and
general testing.`)
@Version(`"moss-container, version %s"("0.1")
Copyright © 2020-2023 Serpent OS Developers
Available under the terms of the Zlib license`)
private struct ContainerCLI
{
    /** Path where the container resides. */
    @Global() @Short("p") @Long("path")
    @Help("Path where the container resides (will be created if non-existent).")
    string path = null;

    @Subcommand()
    Subcommands subcommand;

    void checkPath() {
        if (this.path.empty())
        {
            throw new Exception("path must not be empty");
        }
    }
}


public void run(string[] args) {
    ContainerCLI cli;
    try
    {
        cli = parse!ContainerCLI(args);
    }
    catch (HelpException e) {}
    catch (VersionException e) {}

    cli.checkPath();
    cli.subcommand.match!(
        (Create c) => Create.run(c, cli.path),
        (Remove c) => Remove.run(c, cli.path),
        (Run c) => Run.run(c, cli.path),
    );
}
