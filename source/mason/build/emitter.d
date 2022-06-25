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

module mason.build.emitter;

import mason.build.context : BuildContext;

import moss.format.source.package_definition;
import moss.format.source.source_definition;
import moss.format.binary.payload;
import moss.format.binary.writer;
import moss.deps.analysis;
import std.string : startsWith;
import std.experimental.logger;

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
        import std.array : join;
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
        auto finalPath = join([outputDirectory, pkg.filename], "/");

        auto fp = File(finalPath, "wb");
        auto writer = new Writer(fp);
        scope (exit)
        {
            writer.close();
        }

        infof("Generating package: %s", pkg.filename);

        /* Generate metadata first */
        generateMetadata(analyser, writer, pkg);

        /* Now generate the fileset */
        generateFiles(analyser, writer, pkg);

        writer.flush();
    }

    /**
     * Generate metadata payload
     */
    void generateMetadata(scope Analyser analyser, scope Writer writer, scope Package* pkg) @trusted
    {
        import moss.format.binary.payload.meta : MetaPayload, RecordTag, RecordType;
        import std.algorithm : each, uniq, filter, map, sort;
        import std.array : array;

        auto met = new MetaPayload();
        met.addRecord(RecordType.String, RecordTag.Name, pkg.pd.name);
        met.addRecord(RecordType.String, RecordTag.Version, pkg.source.versionIdentifier);
        met.addRecord(RecordType.Uint64, RecordTag.Release, pkg.source.release);
        met.addRecord(RecordType.Uint64, RecordTag.BuildRelease, pkg.buildRelease);
        met.addRecord(RecordType.String, RecordTag.Summary, pkg.pd.summary);
        met.addRecord(RecordType.String, RecordTag.Description, pkg.pd.description);
        met.addRecord(RecordType.String, RecordTag.Homepage, pkg.source.homepage);

        /* TODO: Be more flexible encoding architecture. */
        import moss.core.platform : platform;

        auto plat = platform();
        met.addRecord(RecordType.String, RecordTag.Architecture, plat.name);

        pkg.source.license.uniq.each!((l) => met.addRecord(RecordType.String,
                RecordTag.License, l));

        auto bucket = analyser.bucket(pkg.pd.name);
        auto providers = bucket.providers();
        auto specifiedDeps = pkg.pd.runtimeDependencies.map!((const n) => fromString!Dependency(n));
        auto discoveredDeps = bucket.dependencies();
        auto dependenciesFull = specifiedDeps.array() ~ discoveredDeps.array();
        dependenciesFull.sort();
        auto dependencies = dependenciesFull.uniq();

        if (!providers.empty)
        {
            foreach (prov; providers)
            {
                infof("[%s] provides %s", pkg.pd.name, prov);
                met.addRecord(RecordType.Provider, RecordTag.Provides, prov);
            }
        }
        if (!dependencies.empty)
        {
            foreach (dep; dependencies)
            {
                infof("[%s] depends on %s", pkg.pd.name, dep);
                met.addRecord(RecordType.Dependency, RecordTag.Depends, dep);
            }
        }

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

            /* We only allow /usr/ paths in moss/boulder, strip the prefix. */
            string fsTarget = file.path[5 .. $];

            switch (le.type)
            {
            case FileType.Regular:
                layoutPayload.addLayout(le, fsTarget, file.digest);
                break;
            case FileType.Symlink:
                layoutPayload.addLayout(le, fsTarget, file.symlinkSource);
                break;
            case FileType.Directory:
                layoutPayload.addLayout(le, fsTarget, cast(ubyte[]) null);
                break;
            default:
                assert(0);
            }
        }

        ulong chunkStartSize = 0;

        /**
         * Insert the unique file into IndexPayload and ContentPayload
         */
        void insertUniqueFile(ref FileInfo file)
        {
            IndexEntry index;
            index.start = chunkStartSize;
            index.end = index.start + file.stat.st_size;
            index.digest = file.digest();

            /* Update next chunk size */
            chunkStartSize = index.end;

            indexPayload.addIndex(index);
            contentPayload.addFile(file.digest, file.fullPath);
        }

        /* For every known file, insert it */
        allFiles.each!((ref f) => insertLayout(f));
        uniqueFiles.each!((ref f) => insertUniqueFile(f));
    }

    Package*[string] packages;
}
