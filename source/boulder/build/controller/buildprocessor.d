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
        super("buildProcessor", ProcessorMode.Branched);
    }

    /**
     * Attempt to allocate some work
     */
    override bool allocateWork()
    {
        return false;
    }

    /**
     * Perform non synchronous work
     */
    override void performWork()
    {

    }

    /**
     * Synchronise results of our work
     */
    override void syncWork()
    {

    }
}
