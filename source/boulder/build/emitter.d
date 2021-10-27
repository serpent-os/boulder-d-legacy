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
import boulder.build.context : BuildContext;
import boulder.build.collector : BuildCollector, FileOrigin;

import moss.format.source.package_definition;
import moss.format.source.source_definition;
import moss.format.binary.payload;
import moss.format.binary.writer;
import moss.deps.analysis;

/**
 * Resulting Package is only buildable once it contains
 * actual files.
 */
package struct Package
{
    PackageDefinition pd;
    SourceDefinition source;

    uint64_t buildRelease = 1;

    /**
     * Resulting filename
     */
    const(string) filename() @safe
    {
        import moss.core.platform : platform;
        import std.string : format;

        auto plat = platform();

        return "%s-%s-%d-%d-%s.stone".format(pd.name, source.versionIdentifier,
                source.release, buildRelease, plat.name);
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
    void emit(const(string) outputDirectory, Analyser analyser) @system
    {
        import std.algorithm : each;

        packages.values.each!((p) => emitPackage(outputDirectory, p, analyser));
    }

private:

    /**
     * Emit a single package into the given working directory
     */
    void emitPackage(const(string) outputDirectory, scope Package* pkg, Analyser analyser) @trusted
    {
        import std.stdio : File, writefln;
        import std.path : buildPath;
        import std.range : empty;

        /* Empty package */
        if (!analyser.hasBucket(pkg.pd.name))
        {
            return;
        }

        /* Magically empty bucket.. */
        if (analyser.bucket(pkg.pd.name).empty)
        {
            return;
        }

        /* Package path */
        auto finalPath = outputDirectory.buildPath(pkg.filename);

        auto fp = File(finalPath, "wb");
        auto writer = new Writer(fp);
        scope (exit)
        {
            writer.close();
        }

        writefln("Creating package %s...", finalPath);

        /* Generate metadata first */
        generateMetadata(writer, pkg);

        /* Now generate the fileset */
        generateFiles(analyser, writer, pkg);

        writer.flush();
    }

    /**
     * Generate metadata payload
     */
    void generateMetadata(scope Writer writer, scope Package* pkg) @trusted
    {
        import moss.format.binary.payload.meta : MetaPayload, RecordTag;
        import std.algorithm : each, uniq;

        auto met = new MetaPayload();
        met.addRecord(RecordTag.Name, pkg.pd.name);
        met.addRecord(RecordTag.Version, pkg.source.versionIdentifier);
        met.addRecord(RecordTag.Release, pkg.source.release);
        met.addRecord(RecordTag.BuildRelease, pkg.buildRelease);
        met.addRecord(RecordTag.Summary, pkg.pd.summary);
        met.addRecord(RecordTag.Description, pkg.pd.description);
        met.addRecord(RecordTag.Homepage, pkg.source.homepage);

        /* TODO: Be more flexible encoding architecture. */
        import moss.core.platform : platform;

        auto plat = platform();
        met.addRecord(RecordTag.Architecture, plat.name);

        pkg.source.license.uniq.each!((l) => met.addRecord(RecordTag.License, l));

        writer.addPayload(met);
    }

    /**
     * Handle emission and inclusion of files
     */
    void generateFiles(Analyser analyser, scope Writer writer, scope Package* pkg) @trusted
    {
        import moss.core : FileType;
        import moss.format.binary.payload.layout : LayoutPayload, LayoutEntry;
        import moss.format.binary.payload.index : IndexPayload, IndexEntry;
        import moss.format.binary.payload.content : ContentPayload;
        import std.algorithm : filter, map, sort, each, uniq;
        import std.array : array;

        /* Add required payloads for files */
        auto contentPayload = new ContentPayload();
        auto indexPayload = new IndexPayload();
        auto layoutPayload = new LayoutPayload();
        writer.addPayload(layoutPayload);
        writer.addPayload(indexPayload);
        writer.addPayload(contentPayload);

        auto bucket = analyser.bucket(pkg.pd.name);
        auto allFiles = bucket.allFiles().array();
        auto uniqueFiles = bucket.uniqueFiles().array();

        /* Keep sorted by path for better data locality + compression */
        uniqueFiles.sort!((a, b) => a.fullPath < b.fullPath);
        allFiles.sort!((a, b) => a.path < b.path);

        /**
         * Insert a LayoutEntry to the payload
         */
        void insertLayout(ref FileInfo file)
        {
            LayoutEntry le;
            /* Clone information from the FileAnalysis into the LayoutEntry */
            le.type = file.type;
            le.uid = file.stat.st_uid;
            le.gid = file.stat.st_gid;
            le.mode = file.stat.st_mode;
            le.time = file.stat.st_ctime;
            if (le.type == FileType.Regular || le.type == FileType.Symlink)
            {
                layoutPayload.addLayout(le, file.data, file.path);
            }
            else if (le.type == FileType.Directory)
            {
                layoutPayload.addLayout(le, null, file.path);
            }
        }

        ulong chunkStartSize = 0;

        /**
         * Insert the unique file into IndexPayload and ContentPayload
         */
        void insertUniqueFile(ref FileInfo file)
        {
            IndexEntry index;
            /* We broke refcounts */
            index.refcount = 0;
            index.size = file.stat.st_size;
            index.start = chunkStartSize;
            index.end = index.size + index.start;

            chunkStartSize = index.end;

            indexPayload.addIndex(index, file.data);
            contentPayload.addFile(file.data, file.fullPath);
        }

        /* For every known file, insert it */
        allFiles.each!((ref f) => insertLayout(f));
        uniqueFiles.each!((ref f) => insertUniqueFile(f));
    }

    Package*[string] packages;
}
