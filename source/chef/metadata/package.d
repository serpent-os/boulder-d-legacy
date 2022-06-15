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
import std.string : format, wrap, detabber;
import std.experimental.logger : tracef;

import chef.metadata.basic;
import chef.metadata.github;

/**
 * known helpers - Most specific first, basic last
 */
static immutable metadataHelpers = ["Github", "Basic",];

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
                    mixin("alias LocalHelperType = " ~ h ~ "Matcher;");
                    LocalHelperType helper = LocalHelperType();
                    auto result = helper.match(uri);
                    if (!result.isNull)
                    {
                        tracef("Using MetataHelper: %s", h);
                        source = result.get;
                        break match_loop;
                    }
                }
            }
            break;
        }
    }

    /**
     * Return correctly formatted metadata section
     */
    string emit()
    {
        import std.string : join, stripRight;
        import std.algorithm : map;

        static immutable recipe = import("recipeTemplate.yml").stripRight;

        string summary = "some as yet undisclosed summary";
        string description = "Some obnoxiously large paragraph that will in turn detail the function of the software and a bunch of info that nobody ever reads";
        string up = upstreams.map!((u) => format!"    - %s : %s"(u.uri, u.plain.hash)).join("\n");
        return format!recipe(source.name, source.versionIdentifier, source.release,
                source.homepage, up, summary, description.wrap(60, "", "    ", 1).stripRight);
    }
}
