/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.controller
 *
 * Provides the core lifecycle for a boulder recipe build
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.controller;

import mason.build.builder;
import mason.build.context;

import std.algorithm : each, filter;
import std.exception : enforce;
import std.file : exists, mkdirRecurse;
import std.path : dirName, absolutePath, baseName;
import std.string : format, endsWith;
import moss.format.source.spec;
import std.parallelism : TaskPool, totalCPUs;
import std.array : join;
import std.experimental.logger;

/**
 * The BuildController is responsible for the main execution cycle of Boulder,
 * and as such, the main entry point for actual builds. It should be noted that
 * as the build process can be one that hangs execution, it is run on a separate
 * thread.
 */
public final class BuildController
{
    @disable this();

    this(string architecture)
    {
        if (architecture == "native")
        {
            import moss.core.platform : platform;

            architecture = platform().name;
        }
        this.architecture = architecture;
        infof("Architecture: %s", architecture);
    }
    /**
     * Request that we begin building the given path
     */
    bool build(const(string) path)
    {
        enforce(path.exists,
                "BuildController.build(): Cannot build %s as it does not exist".format(path));
        enforce(path.endsWith(".yml"),
                "BuildController.build(): Path does not look like a valid YML file: %s".format(
                    path));

        if (builder !is null)
        {
            builder.destroy();
        }

        /* Set up the new builder */
        auto s = new Spec(File(path, "r"));
        s.parse();

        buildContext.spec = s;
        buildContext.specDir = path.dirName.absolutePath;

        builder = new Builder(architecture);

        static struct Step
        {
            bool delegate() command;
            string name;
        }

        Step[] steps = [
            Step(&stagePrepare, "Prepare"), Step(&stageBuild, "Build"),
            Step(&stageAnalyse, "Analyse"), Step(&stageEmit,
                    "Emit packages"), Step(&stageManifest, "Emit manifest"),
        ];

        foreach (ref step; steps)
        {
            auto ret = runTimed(step.command, step.name);
            if (!ret)
            {
                return false;
            }
        }

        return true;
    }

    /**
     * Run preparation for the package
     */
    bool stagePrepare()
    {
        builder.prepareRoot();
        builder.preparePkgFiles();
        return true;
    }

    /**
     * Build the package profiles
     */
    bool stageBuild()
    {
        return builder.buildProfiles();
    }

    /**
     * Analyse + collect
     */
    bool stageAnalyse()
    {
        builder.collectAssets();
        return true;
    }

    /**
     * Emit packages
     */
    bool stageEmit()
    {
        builder.emitPackages();
        return true;
    }

    /**
     * Product manifest files
     */
    bool stageManifest()
    {
        builder.produceManifests();
        return true;
    }

private:

    bool runTimed(bool delegate() dg, in string label)
    {
        import std.datetime.stopwatch : StopWatch, AutoStart;

        auto sw = StopWatch(AutoStart.yes);
        scope (exit)
        {
            infof("[%s] Finished: %s", label, sw.peek);
        }
        return dg();
    }

    Builder builder = null;
    string architecture = "native";
}
