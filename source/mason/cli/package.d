/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.cli
 *
 * Module namespace imports & MasonCLI definition
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.cli;

import core.sys.posix.unistd : isatty;
import std.sumtype;

import dopt;
import mason.cli.cmdbuild;
import moss.core.logger;

private alias Subcommands = SumType!(Build);

/**
 * The MasonCLI type holds some global configuration bits
 */
@Command("mason")
@Help("Build stone packages using YML recipes.")
private struct MasonCLI
{
    @Global() @Long("no-color") @Help("Do not color console output")
    bool noColor = false;

    /** When set to true, we enable debug output */
    @Option() @Short("d") @Long("debug") @Help("Enable debugging output")
    bool debugMode = false;

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
    MasonCLI cli;
    try
    {
        cli = parse!MasonCLI(args);
    }
    catch (DoptException e)
    {
        /* User requested the version or the help string. That's OK. */
        return 0;
    }
    cli.setLogger();
    try
    {
        cli.subcommand.match!(
            (Build c) => c.run(),
        );
    }
    catch (Exception e)
    {
        fatal(e.msg);
        return -1;
    }
    return 0;
}
