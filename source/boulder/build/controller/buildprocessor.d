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

module boulder.build.controller.buildprocessor;

import moss.jobs;
import boulder.build.builder;
import boulder.build.context;
import moss.format.source.spec;
import std.path : dirName, absolutePath;

/**
 * A BuildRequest is sent to the BuildController to begin building of a given
 * moss source.
 */
@Job struct BuildRequest
{
    /**
     * Fully qualified path to the YAML source
     */
    string ymlSource;

    /**
     * The real specFile
     */
    Spec* specFile;
}

/**
 * Provide stateful processing for the BuildProcessor allowing it to manage
 * a job in a reentrant, loop tidy fashion.
 */
enum BuildState
{
    /**
     * We have no active work, so we can accept work now.
     */
    Idle = 0,

    /**
     * Preparate the root trees
     */
    Prepare,

    /**
     * Fetching the sources
     */
    Fetch,

    /**
     * Build the package
     */
    Build,

    /**
     * Analyse the contents
     */
    Analyse,

    /**
     * Emit the package
     */
    ProducePackages,

    /**
     * Emit the source build manifest
     */
    ProduceManifest,

    /**
     * Completed successfully
     */
    Complete,

    /**
     * Failed to build for whatever reason
     */
    Failed,
}

/**
 * The  BuildProcessor is responsible for accepting a BuildRequest and processing
 * the entire lifecycle of it
 */
public final class BuildProcessor : SystemProcessor
{
    /**
     * Construct a new BuildProcessor operating on a separate thread
     */
    this()
    {
        super("buildProcessor", ProcessorMode.Main);
        buildContext.jobSystem.registerJobType!BuildRequest;
    }

    /**
     * Attempt to allocate some work
     */
    override bool allocateWork()
    {
        if (state == BuildState.Idle && buildContext.jobSystem.claimJob(job, req))
        {
            return true;
        }

        return state != BuildState.Idle;
    }

    /**
     * Perform non synchronous work
     */
    override void performWork()
    {
        import std.stdio : writefln;
        import std.datetime.stopwatch : StopWatch, AutoStart;

        /* Report how long function execution takes */
        auto sw = StopWatch(AutoStart.yes);
        scope (exit)
        {
            sw.stop();
            if (state != BuildState.Complete && state != BuildState.Failed
                    && state != BuildState.Idle)
            {
                writefln(" ==> 'BuildState.%s' finished [%s]", state, sw.peek);
            }
        }

        switch (state)
        {
        case BuildState.Prepare:
            currentBuilder.prepareRoot();
            /* TODO: Move sources + Pkgfiles to fetch jobs */
            currentBuilder.prepareSources();
            currentBuilder.preparePkgFiles();
            break;
        case BuildState.Build:
            currentBuilder.buildProfiles();
            break;
        case BuildState.Analyse:
            currentBuilder.collectAssets();
            break;
        case BuildState.ProducePackages:
            currentBuilder.emitPackages();
            break;
        case BuildState.ProduceManifest:
            currentBuilder.produceManifests();
            break;
        default:
            break;
        }
    }

    /**
     * Synchronise results of our work
     */
    override void syncWork()
    {
        final switch (state)
        {
            /* Transition to preparation */
        case BuildState.Idle:
            clear();
            state = BuildState.Prepare;
            buildContext.spec = req.specFile;
            buildContext.specDir = req.ymlSource.dirName.absolutePath;
            currentBuilder = new Builder();
            break;
        case BuildState.Prepare:
            state = BuildState.Fetch;
            break;
        case BuildState.Fetch:
            state = BuildState.Build;
            break;
        case BuildState.Build:
            state = BuildState.Analyse;
            break;
        case BuildState.Analyse:
            state = BuildState.ProducePackages;
            break;
        case BuildState.ProducePackages:
            state = BuildState.ProduceManifest;
            break;
        case BuildState.ProduceManifest:
            state = BuildState.Complete;
            break;
        case BuildState.Complete:
            clear();
            buildContext.jobSystem.finishJob(job.jobID, JobStatus.Completed);
            break;
        case BuildState.Failed:
            clear();
            buildContext.jobSystem.finishJob(job.jobID, JobStatus.Failed);
            break;
        }
    }

private:

    /**
     * Helper to clear the current state out
     */
    void clear()
    {
        if (currentBuilder !is null)
        {
            currentBuilder.destroy();
            currentBuilder = null;
        }
        state = BuildState.Idle;
    }

    BuildRequest req;
    JobIDComponent job;

    /**
     * Current working state
     */
    BuildState state = BuildState.Idle;

    Builder currentBuilder = null;
}
