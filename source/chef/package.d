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
import std.exception : enforce;
import std.path : baseName;
import std.range : empty;

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
        controller = new FetchController();
        analyser = new Analyser();
        controller.onFail.connect(&onFail);
        controller.onComplete.connect(&onComplete);
    }

    void onFail(in Fetchable f, in string msg)
    {
        import std.stdio : stderr;

        stderr.writeln(msg);
    }

    void onComplete(in Fetchable f, long code)
    {
        import std.stdio : writeln;

        writeln("ret: ", code);
        if (code == 200)
        {
            processPaths ~= f.destinationPath;
            writeln("Fetched: ", f.destinationPath);
            return;
        }
        onFail(f, "Server returned non-200 status code");
    }

    /**
     * Run Chef lifecycle to completion
     */
    void run()
    {
        import std.stdio : writeln;

        while (!controller.empty)
        {
            controller.fetch();
        }

        if (processPaths.empty)
        {
            writeln("Nothing for us to process, exiting");
            return;
        }

        writeln("Processing: ", processPaths);
    }
    /**
     * Add some kind of input URI into chef for ... analysing
     */
    void addSource(string uri, UpstreamType type = UpstreamType.Plain)
    {
        enforce(type == UpstreamType.Plain, "Chef only supports plain sources");
        auto f = Fetchable(uri, "/tmp/boulderChefURI-XXXXXX", 0, FetchType.TemporaryFile, null);
        controller.enqueue(f);
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
    FetchController controller;
    Analyser analyser;
    string[] processPaths;
}
