/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.emitter
 *
 * Package emission APIs
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.emitter;

import mason.build.context : BuildContext;

import mason.build.manifest;
import moss.deps.analysis;
import moss.format.binary.payload;
import moss.format.binary.writer;
import moss.format.source.package_definition;
import moss.format.source.source_definition;
import std.experimental.logger;
import std.string : format, startsWith, endsWith;

/**
 * The BuildEmitter is used to emit build assets from the build, collection +
 * analysis routines, into an actual package.
 */
public class BuildEmitter
{

    @disable this();

    /**
     * Construct new BuildEmitter for the system architecture
     */
    this(string systemArch) @safe
    {
        if (systemArch == "native")
        {
            import moss.core.platform : platform;

            systemArch = platform().name;
        }
        binaryManifest = new BuildManifestBinary(systemArch);
        jsonManifest = new BuildManifestJSON(systemArch);
    }

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
        binaryManifest.write();
        jsonManifest.write();
    }

private:

    /**
     * Emit a single package into the given working directory
     */
    void emitPackage(const(string) outputDirectory, scope Package* pkg, Analyser analyser) @trusted
    {
        import std.stdio : File;
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

        info(format!"Generating package: %s"(pkg.filename));

        /* Generate metadata first */
        auto bucket = analyser.bucket(pkg.pd.name);
        auto mp = generateMetadata(bucket, pkg);
        writer.addPayload(mp);

        /* Now generate the fileset */
        auto lp = generateFiles(bucket, writer, pkg);

        emitManifest(pkg, analyser.bucket(pkg.pd.name), lp);

        writer.flush();
    }

    /**
     * Handle emission and inclusion of files
     */
    LayoutPayload generateFiles(scope AnalysisBucket bucket, scope Writer writer, scope Package* pkg) return @trusted
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

        return layoutPayload;
    }

    /**
     * Handle per-pkg emission
     */
    void emitManifest(scope Package* pkg, scope AnalysisBucket bucket, scope LayoutPayload lp) @safe
    {
        if (pkg.pd.name.endsWith("-dbginfo"))
        {
            return;
        }
        binaryManifest.recordPackage(pkg, bucket, lp);
        jsonManifest.recordPackage(pkg, bucket, lp);
    }

    Package*[string] packages;

    /**
     * Human readable manifest
     */
    BuildManifestJSON jsonManifest;

    /**
     * Binary manifest for machinery integration
     */
    BuildManifestBinary binaryManifest;
}
