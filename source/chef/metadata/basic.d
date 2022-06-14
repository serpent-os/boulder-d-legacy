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

/**
 * Standard/basic version detection
 */
private static auto reBasicVersion = ctRegex!(r"^([a-zA-Z0-9-]+)-([a-zA-Z0-9._-]+)\.(zip|tar|sh|bin\.*)");

public struct BasicMatcher
{
    /**
     * Not yet implemented
     */
    Nullable!(SourceDefinition, SourceDefinition.init) match(in string uri)
    {
        Nullable!(SourceDefinition, SourceDefinition.init) ret = SourceDefinition.init;

        return ret;
    }
}