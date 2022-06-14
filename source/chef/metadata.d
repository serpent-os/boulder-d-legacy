/* SPDX-License-Identifier: Zlib */

/**
 * Chef - Metadata manipulation
 *
 * Metadata management from sources
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module chef.metadata;

import moss.format.source;
import std.regex;

/**
 * Standard/basic version detection
 */
auto reBasicVersion = ctRegex!(r"^([a-zA-Z0-9-]+)-([a-zA-Z0-9._-]+)\.(zip|tar|sh|bin\.*)");

/**
 * Github automatically generated downloads
 */
auto reGithubAutomatic = ctRegex!(
        r"\w+\:\/\/github\.com\/([A-Za-z0-9-_]+)\/([A-Za-z0-9-_]+)\/archive\/refs\/tags\/([A-Za-z0-9.-_]+)\.(tar|zip)");

/**
 * Manually uploaded files on GitHub
 */
auto reGithubManual = ctRegex!(
        r"\w+\:\/\/github\.com\/([A-Za-z0-9-_]+)\/([A-Za-z0-9-_]+)\/releases\/download\/([A-Za-z0-9-_.]+)\/.*");
/**
 * Metadata provides the methods and members required to manipulate
 * and detect Metadata for a package.
 */
public struct Metadata
{
    SourceDefinition source;
    UpstreamDefinition[] upstreams;

    /**
     * If our source is empty, try to update it from the given URI
     */
    void updateSource(in string uri)
    {
        if (source != SourceDefinition.init)
        {
            return;
        }
    }
}
