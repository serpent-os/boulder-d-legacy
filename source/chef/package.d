/* SPDX-License-Identifier: Zlib */

/**
 * Chef - Recipe Manipulation
 *
 * Generation and manipulation of source recipe files that can then be consumed
 * by boulder.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module chef;

import moss.fetcher;
import moss.deps.analysis;
public import moss.format.source.upstream_definition;

/**
 * Main class for analysis of incoming sources to generate an output recipe
 */
public final class Chef
{
    /**
     * Construct a new Chef
     */
    this()
    {
        fetcher = new FetchController();
    }

    void addSource(string uri, UpstreamType type = UpstreamType.Plain)
    {

    }

    /**
     * Recipe name
     */
    pure @property immutable(string) recipeName() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _recipeName;
    }

    /**
     * Recipe version
     */
    pure @property immutable(string) recipeVersion() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _recipeVersion;
    }

private:

    string _recipeName;
    string _recipeVersion;
    static const uint64_t recipeRelease = 0;
    static const(string) recipeFile = "stone.yml";
    FetchController fetcher;
}