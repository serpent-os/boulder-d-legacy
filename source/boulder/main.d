/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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
