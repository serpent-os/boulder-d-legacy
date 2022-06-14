/* SPDX-License-Identifier: Zlib */

/**
 * Basic metadata support
 *
 * Ultra simple matching.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module chef.metadata.basic;

import std.typecons : Nullable;
import moss.format.source.source_definition;
import std.regex;
import std.path : baseName, dirName;

/**
 * Standard/basic version detection
 */
private static auto reBasicVersion = ctRegex!(
        r"^([a-zA-Z0-9-]+)-([a-zA-Z0-9._-]+)\.(zip|tar|sh|bin\.*)");

private static enum BasicIndex : int
{
    Name = 1,
    Version = 2,
}

/**
 * Fallback policy for matching things.
 */
public struct BasicMatcher
{
    /**
     *  Match against the URI basename
     */
    Nullable!(SourceDefinition, SourceDefinition.init) match(in string uri)
    {
        Nullable!(SourceDefinition, SourceDefinition.init) ret = SourceDefinition.init;

        auto m = uri.baseName.matchFirst(reBasicVersion);
        if (m.empty)
        {
            return ret;
        }

        auto sd = SourceDefinition();
        sd.name = m[BasicIndex.Name];
        sd.versionIdentifier = m[BasicIndex.Version];
        sd.homepage = uri.dirName;
        return Nullable!(SourceDefinition, SourceDefinition.init)(sd);
    }
}
