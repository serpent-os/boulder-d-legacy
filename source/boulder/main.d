/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.main
 *
 * Main entry point for our binary
 *
 * Through symlink names (in `/usr`) we provide the main entry point
 * for both `mason` and `boulder`. This decision was made to avoid
 * having two binaries which would honestly just be bloat.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module main;

import std.path : baseName;

static import boulder.cli;
static import mason.cli;

int main(string[] args)
{
    const auto programName = args[0].baseName;
    switch (programName)
    {
    case "mason":
        return mason.cli.run(args);
    default:
        return boulder.cli.run(args);
    }
}
