/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2022 Serpent OS Developers
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

module boulder.controller;

import moss.format.source;
import std.exception : enforce;
import std.stdio : File, writeln;

import boulder.buildjob;

alias RecipeStageFunction = RecipeStageReturn delegate();

enum RecipeStageReturn
{
    Skip,
    Succeed,
    Fail,
}

struct RecipeStage
{
    string name;
    RecipeStageFunction functor;
}

/**
 * This is the main entry point for all build commands which will be dispatched
 * to mason in the chroot environment via moss-container.
 */
public final class Controller
{
    this()
    {
        /* Construct recipe stages here */
        stages = [
            RecipeStage("clean-root", &cleanRoot),
            RecipeStage("fetch-sources", &fetchSources),
            RecipeStage("prepare-root", &prepareRoot),
            RecipeStage("stage-sources", &stageSources),
            RecipeStage("configure-rootfs", &configureRootfs),
            RecipeStage("install-rootfs", &installRootfs),
            RecipeStage("run-build", &runBuild),
            RecipeStage("collect-artefacts", &collectArtefacts),
        ];
    }

    /**
     * Begin the build process for a specific recipe
     */
    void build(in string filename)
    {
        auto fi = File(filename, "r");
        recipe = new Spec(fi);
        recipe.parse();

        auto job = new BuildJob(recipe, filename);
        writeln(job.guestPaths);
        writeln(job.hostPaths);
        scope (exit)
        {
            fi.close();
        }

        int stageIndex = 0;
        int nStages = cast(int) stages.length;

        build_loop: while (true)
        {
            /* Dun dun dun */
            if (stageIndex > nStages - 1)
            {
                break build_loop;
            }

            RecipeStage* stage = &stages[stageIndex];
            enforce(stage.functor !is null);

            writeln("[boulder] ", stage.name);
            auto result = stage.functor();
            final switch (result)
            {
            case RecipeStageReturn.Fail:
                writeln("[boulder] Failed ", stage.name);
                break build_loop;
            case RecipeStageReturn.Succeed:
                writeln("[boulder] Success ", stage.name);
                ++stageIndex;
                break;
            case RecipeStageReturn.Skip:
                writeln("[boulder] Skipped ", stage.name);
                ++stageIndex;
                break;
            }
        }
    }

    /**
     * Clean roots for build
     */
    RecipeStageReturn cleanRoot()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Fetch missing sources
     */
    RecipeStageReturn fetchSources()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Prepare/create roots
     */
    RecipeStageReturn prepareRoot()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Stage sources for the build
     */
    RecipeStageReturn stageSources()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Configure the rootfs properties
     */
    RecipeStageReturn configureRootfs()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Install the rootfs
     */
    RecipeStageReturn installRootfs()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Run the build
     */
    RecipeStageReturn runBuild()
    {
        return RecipeStageReturn.Fail;
    }

    /**
     * Collect all of the artefacts
     */
    RecipeStageReturn collectArtefacts()
    {
        return RecipeStageReturn.Fail;
    }

    Spec* recipe = null;
    RecipeStage[] stages;
}
