/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.cli
 *
 * Module namespace imports & core CLI definition
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.cli;

import core.sys.posix.unistd : isatty;
import std : stderr;
import std.sumtype;
import std.format : format;

import boulder.cli.cmdbuild;
import boulder.cli.cmdchroot;
import boulder.cli.cmddeletecache;
import boulder.cli.cmdnew;
import boulder.environment : fullVersion;
import dopt;
import moss.core.logger;

private alias Subcommands = SumType!(Build, Chroot, DeleteCache, New);

/**
 * The BoulderCLI type holds some global configuration bits
 */
@Command("boulder")
@Help("Produce packages for moss. A core component of the Serpent tooling.")
@Version(format!`boulder, version %s
Copyright © 2020-2023 Serpent OS Developers
Available under the terms of the Zlib license`(fullVersion()))
private struct BoulderCLI
{
    @Global() @Long("no-color") @Help("Do not color console output")
    bool noColor = false;

    /** When set to true, we enable debug output */
    @Global @Short("d") @Long("debug") @Help("Enable debugging output")
    bool debugMode = false;

    /** Specific build configuration profile to use */
    @Global @Short("p") @Long("profile") @Help("Override default build profile")
    string profile = "default-x86_64";

    /** Where to find the root of configurations (/etc + /usr) */
    @Global @Short("C") @Long("config-directory") @Help("Root directory for configurations")
    string configDir;

    @Subcommand()
    Subcommands subcommand;

    void setLogger()
    {
        auto logOpts = ColorLoggerFlags.Timestamps;
        if (isatty(0) && isatty(1) && !this.noColor)
        {
            logOpts |= ColorLoggerFlags.Color;
        }
        if (this.debugMode)
        {
            globalLogLevel = LogLevel.trace;
        }
        configureLogger(logOpts);
    }
}

public int run(string[] args) {
    BoulderCLI cli;
    try
    {
        cli = parse!BoulderCLI(args);
    }
    catch (DoptException e)
    {
        return 0;
    }
    cli.setLogger();
    try
    {
        cli.subcommand.match!(
            (Build c) => c.run(cli.configDir, cli.profile),
            (Chroot c) => c.run(cli.configDir, cli.profile),
            (DeleteCache c) => c.run(),
            (New c) => c.run(),
        );
    }
    catch (Exception e)
    {
        stderr.writeln(e.msg);
        return -1;
    }
    return 0;
}
