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

module boulder.build.manifest;

import boulder.build.context;
import boulder.build.collector;
import std.path : buildPath;
import std.stdio : File;
import std.conv : to;
import std.json;

/**
 * A BuildManifest is produced for each BuildProfile and contains some
 * data which we can use to verify that a source recipe has indeed been
 * build-verified.
 *
 * Additionally it provides important information to supplement the source
 * index for build-time results, i.e. subpackage yields, etc.
 */
public final class BuildManifest
{
    /**
     * Disallow default constructor
     */
    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture)
    {
        import std.string : format;

        /* i.e. manifest.x86_64 */
        _fileName = "manifest.%s.json".format(architecture);
        _binFileName = "manifest.%s.bin".format(architecture);
    }

    /**
     * Return the file name for the manifest (not the full path)
     */
    pure @property string fileName() const @safe @nogc nothrow
    {
        return _fileName;
    }

    /**
     * Return the binary file name for the manifest (not the full path)
     */
    pure @property string binFileName() const @safe @nogc nothrow
    {
        return _binFileName;
    }

    /**
     * Save the manifest (useful only for future manifest).
     * This is considered a build artefact, but for development purposes
     * the file should then be stashed in git for verified builds.
     */
    void save(ref BuildCollector collector) @safe
    {
        import std.algorithm : sort;
        import std.array : array;

        auto names = collector.targets.array;
        names.sort();

        import std.stdio : writeln;

        writeln(names);
        writeHumanReadableReport(collector);
    }

    /**
     * Load the manifest from the same directory that we found the specFile in
     */
    void load() @safe
    {
        auto sourcePath = buildContext.specDir.buildPath(binFileName);
    }

private:

    /**
     * A human readable JSON report is emitted. We don't ever load these.
     */
    void writeHumanReadableReport(ref BuildCollector col) @safe
    {
        auto targetPath = buildContext.outputDirectory.buildPath(fileName);
        auto fp = File(targetPath, "w");
        scope (exit)
        {
            fp.close();
        }

        /* Root values required in the manifest. */
        JSONValue rootVals = [
            "manifest-version": "0.1",
            "source-name": buildContext.spec.source.name,
            "source-release": to!string(buildContext.spec.source.release),
            "source-version": to!string(buildContext.spec.source.versionIdentifier),

        ];

        fp.write("/** Human readable report. This is not consumed by boulder */\n");
        fp.write(rootVals.toPrettyString);
        fp.write("\n");

        /* TODO: Merge collected package names, then provides */
    }

    string _fileName = null;
    string _binFileName = null;
}
