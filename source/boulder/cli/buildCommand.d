/*
 * This file is part of boulder.
 *
 * Copyright © 2020 Serpent OS Developers
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
 * 2. Altered source builds must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.cli.buildCommand;

public import moss.cli;
import moss;
import std.stdio;
import boulder.build;

/**
 * The BoulderCLI type holds some global configuration bits
 */
@CommandName("build") @CommandAlias("bi")
@CommandHelp("Build a package",
        "Build a binary package from the given package specification file. It will
be built using the locally available build dependencies and the resulting
binary packages (.stone) will be emitted to the output directory, which
defaults to the current working directory.")
@CommandUsage("[spec]")
public final struct BuildCommand
{
    BaseCommand pt;
    alias pt this;

    @CommandEntry() int run(ref string[] argv)
    {
        import std.algorithm;
        import std.file : exists;
        import std.exception : enforce;
        import std.string : format;

        /* We only want a unique set of paths built */
        auto buildPaths = argv.uniq;

        /* Ensure each path exists.. */
        void validatePath(const(string) p)
        {
            enforce(p.exists, "Path does not exist: %s".format(p));
        }

        /* Build each passed path */
        void buildPath(const(string) p)
        {
            auto builder = Builder(p);
            auto name = "%s %s".format(builder.specFile.source.name,
                    builder.specFile.source.versionIdentifier);
            writefln("Building ", name);
            builder.build();
        }

        if (argv.length < 1)
        {
            writeln("No source packages provided to build CLI");
            return ExitStatus.Failure;
        }

        buildPaths.each!((e) => validatePath(e));
        buildPaths.each!((e) => buildPath(e));

        return ExitStatus.Success;
    }
}
