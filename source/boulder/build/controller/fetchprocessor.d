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

module boulder.build.controller.fetchprocessor;

import boulder.build.context;
import moss.jobs;
import moss.format.source.upstream_definition;

/**
 * FetchJob simply wraps an Upstream
 */
public @Job struct FetchJob
{
    /**
     * The upstream to fetch
     */
    UpstreamDefinition upstream;
}

/**
 * The FetchProcessor is responsible for managing simplistic requests to fetch
 * a file and store it at a give location. Each FetchProcessor is only capable
 * of retrieving a single file at a time, so it actually makes sense to 
 */
public final class FetchProcessor : SystemProcessor
{
    this()
    {
        super("fetchProcessor", ProcessorMode.Branched);
    }

    override bool allocateWork()
    {
        return buildContext.jobSystem.claimJob(job, req);
    }

    override void performWork()
    {
        import std.stdio : writeln;

        writeln("Fetching: ", req.upstream);
    }

    override void syncWork()
    {
        buildContext.jobSystem.finishJob(job.jobID, JobStatus.Completed);
    }

private:

    JobIDComponent job;
    FetchJob req;
}
