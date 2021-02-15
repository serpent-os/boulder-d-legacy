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

module boulder.build.emitter;

import boulder.build.analysis;
import boulder.build.collector : BuildCollector;

import moss.format.source.package_definition;
import moss.format.source.source_definition;
import moss.format.binary.writer;

/**
 * Resulting Package is only buildable once it contains
 * actual files.
 */
package struct Package
{
    PackageDefinition pd;
    SourceDefinition source;

    /**
     * Resulting filename
     */
    const(string) filename() @safe
    {
        import moss.core.platform : platform;
        import std.string : format;

        auto plat = platform();

        return "%s-%s-%d-%s.stone".format(pd.name, source.versionIdentifier,
                source.release, plat.name);
    }
}

/**
 * The BuildEmitter is used to emit build assets from the build, collection +
 * analysis routines, into an actual package.
 */
struct BuildEmitter
{

public:

    /**
     * Add a package to the BuildEmitter. It is unknown whether or not
     * a package will actually be emitted until such point as files are
     * added to it.
     */
    void addPackage(ref SourceDefinition sd, ref PackageDefinition pd) @safe
    {
        auto pkg = new Package();
        pkg.pd = pd;
        pkg.source = sd;
        packages[pd.name] = pkg;
    }

    /**
     * Now emit the collected packages
     */
    void emit(const(string) outputDirectory, ref BuildCollector col) @system
    {
        import std.algorithm : each;

        packages.values.each!((p) => emitPackage(outputDirectory, p, col));
    }

private:

    /**
     * Emit a single package into the given working directory
     */
    void emitPackage(const(string) outputDirectory, scope Package* pkg, ref BuildCollector col) @trusted
    {
        import std.stdio : File, writefln;
        import std.path : buildPath;
        import std.algorithm : filter, map, sort, each;
        import std.range : empty;
        import moss.format.binary.legacy : FileType;
        import std.array : array;

        auto finalPath = outputDirectory.buildPath(pkg.filename);

        /* No files, no package. */
        auto fileSet = col.filesForTarget(pkg.pd.name);
        if (fileSet.empty)
        {
            return;
        }
        fileSet.sort!((a, b) => a.path < b.path);

        auto dupeSet = fileSet.filter!((ref m) => m.type == FileType.Regular)
            .map!((ref m) => col.originForFile(m))
            .array;
        dupeSet.sort!((a, b) => a.hash < b.hash);

        /* Open the output file */
        auto fp = File(finalPath, "wb");
        auto writer = new Writer(fp);
        scope (exit)
        {
            writer.close();
        }

        writefln("Creating package %s...", finalPath);

        import moss.format.binary.payload.meta : MetaPayload, RecordTag;

        auto met = new MetaPayload();
        met.addRecord(RecordTag.Name, pkg.pd.name);
        met.addRecord(RecordTag.Version, pkg.source.versionIdentifier);
        met.addRecord(RecordTag.Release, pkg.source.release);
        met.addRecord(RecordTag.Summary, pkg.pd.summary);
        met.addRecord(RecordTag.Description, pkg.pd.description);
        met.addRecord(RecordTag.Homepage, pkg.source.homepage);
        writer.addPayload(met);

        writer.flush();
    }

    Package*[string] packages;
}
