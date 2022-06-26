/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Module Name (use e.g. 'moss.core.foo.bar')
 *
 * Module Description (FIXME)
 *
 * In package.d files containing only imports and nothing else,
 * 'Module namespace imports.' is sufficient description.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module main;

import boulder.cli;
import mason.cli;
import moss.core.logging;
import std.path : baseName;
import std.stdio;

/**
 * Handle main entry for the boulder subtool
 */
int boulderMain(string[] args)
{
    auto clip = cliProcessor!BoulderCLI(args);
    clip.addCommand!BuildControlCommand;
    clip.addCommand!NewCommand;
    clip.addCommand!VersionCommand;
    clip.addCommand!HelpCommand;
    return clip.process(args);
}

/**
 * Handle main entry for the mason subtool
 */
int masonMain(string[] args)
{
    auto clip = cliProcessor!MasonCLI(args);
    clip.addCommand!BuildCommand;
    clip.addCommand!HelpCommand;
    return clip.process(args);
}

int main(string[] args)
{
    configureLogging(ColorLoggerFlags.Color | ColorLoggerFlags.Timestamps);

    auto programName = args[0].baseName;
    switch (programName)
    {
    case "mason":
        return masonMain(args);
    default:
        return boulderMain(args);
    }
}
