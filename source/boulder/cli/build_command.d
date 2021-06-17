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
 * 2. Altered source builds must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.cli.build_command;

public import moss.core.cli;
import moss.core;
import std.stdio;
import boulder.build;
import boulder.cli : BoulderCLI;

/**
 * The BuildCommand is responsible for handling requests to build stone.yml
 * formatted files into useful binary packages.
 */
@CommandName("build") @CommandAlias("bi")
@CommandHelp("Build a package",
        "Build a binary package from the given package specification file. It will
be built using the locally available build dependencies and the resulting
binary packages (.stone) will be emitted to the output directory, which
defaults to the current working directory.")
@CommandUsage("[spec]")
public struct BuildCommand
{
    /** Extend BaseCommand with BuildCommand specific functionality */
    BaseCommand pt;
    alias pt this;

    /**
     * Main enty point into the BuildCommand. We expect a list of paths that
     * contain "stone.yml" formatted build description files. For each path
     * we encounter, we initially check the validity and existence.
     *
     * Once all validation is passed, we begin building all of the passed
     * file paths into packages.
     */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.algorithm : each, uniq;
        import std.file : exists;
        import std.exception : enforce;
        import std.string : format;

        /* Ensure each path exists.. */
        void validatePath(const(string) p)
        {
            enforce(p.exists, "Path does not exist: %s".format(p));
        }

        /* Build each passed path */
        void buildPath(const(string) p)
        {
            auto builder = Builder(p);
            buildContext.jobs = jobs;
            buildContext.outputDirectory = pt.findAncestor!BoulderCLI.outputDirectory;
            auto name = "%s %s".format(buildContext.spec.source.name,
                    buildContext.spec.source.versionIdentifier);
            writefln("Building ", name);
            builder.build();
        }

        if (argv.length < 1)
        {
            writeln("No source packages provided to build CLI");
            return ExitStatus.Failure;
        }

        argv.uniq.each!((e) => validatePath(e));
        argv.uniq.each!((e) => buildPath(e));

        return ExitStatus.Success;
    }

    /** Specify the number of build jobs to execute in parallel. */
    @Option("j", "jobs", "Set the number of parallel build jobs (0 = automatic)") int jobs = 0;
}
