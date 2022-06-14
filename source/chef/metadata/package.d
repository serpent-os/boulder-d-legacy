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
import std.typecons : Nullable;
import std.experimental.typecons : wrap;

import chef.metadata.basic;
import chef.metadata.github;

/**
 * known helpers - Most specific first, basic last
 */
static immutable metadataHelpers = ["Github", "Basic",];

/**
 * Interface for SourceMatcher types to provide the correct SourceDefinition
 */
public interface SourceMatcher
{
    /**
     * Return null if no match is found
     */
    Nullable!(SourceDefinition, SourceDefinition.init) match(in string uri);
}

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

        /* Part loop, part CTFE, allow walking all helpers and grab results */
        match_loop: while (true)
        {
            static foreach (h; metadataHelpers)
            {
                {
                    mixin("alias LocalHelperType = " ~ h  ~ "Matcher;");
                    LocalHelperType helper = LocalHelperType();
                    auto result = helper.match(uri);
                    if (!result.isNull)
                    {
                        source = result.get;
                        break match_loop;
                    }
                }
            }
            break;
        }
    }
}
