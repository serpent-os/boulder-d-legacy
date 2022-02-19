/* SPDX-License-Identifier: Zlib */

/**
 * Upstream Cache
 *
 * Path mangling for retention of sources
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.upstreamcache;

import std.path : buildPath;
import std.file : mkdirRecurse;
public import moss.format.source.upstream_definition;

/**
 * The UpstreamCache provides persistent paths and
 * deduplication facilities to permit retention of
 * hash-indexed downloads across multiple builds.
 */
public final class UpstreamCache
{

    /**
     * Only allow Boulder to construct us.
     */
    package this()
    {

    }

    /**
     * Construct all required directories
     */
    void constructDirs()
    {
        auto paths = [
            rootDirectory, stagingDirectory, gitDirectory, plainDirectory
        ];
        foreach (p; paths)
        {
            p.mkdirRecurse();
        }
    }

private:

    /**
     * Base of all directories
     */
    static immutable(string) rootDirectory = "/var/cache/boulder/upstreams";

    /**
     * Staging downloads that might be wonky.
     */
    static immutable(string) stagingDirectory = rootDirectory.buildPath("staging");

    /**
     * Git clones
     */
    static immutable(string) gitDirectory = rootDirectory.buildPath("git");

    /**
     * Plain downloads
     */
    static immutable(string) plainDirectory = rootDirectory.buildPath("fetched");
}
