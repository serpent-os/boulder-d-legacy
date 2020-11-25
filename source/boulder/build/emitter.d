/*
 * This file is part of boulder.
 *
 * Copyright © 2020 Serpent OS Developers
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

import moss.format.source.packageDefinition;
import moss.format.source.sourceDefinition;
import moss.format.binary.writer;
import moss.format.binary.payload;
import moss.format.binary.contentPayload;
import moss.format.binary.index;
import moss.format.binary.indexPayload;
import moss.format.binary.metaPayload;
import moss.format.binary.layout;
import moss.format.binary.layoutPayload;
import moss.format.binary.record;

/**
 * Resulting Package is only buildable once it contains
 * actual files.
 */
package final struct Package
{
    PackageDefinition pd;
    SourceDefinition source;

    /**
     * Resulting filename
     */
    final const(string) filename() @safe
    {
        import moss.platform : platform;
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
final struct BuildEmitter
{

public:

    /**
     * Add a package to the BuildEmitter. It is unknown whether or not
     * a package will actually be emitted until such point as files are
     * added to it.
     */
    final void addPackage(ref SourceDefinition sd, ref PackageDefinition pd) @safe
    {
        auto pkg = new Package();
        pkg.pd = pd;
        pkg.source = sd;
        packages[pd.name] = pkg;
    }

    /**
     * Now emit the collected packages
     */
    final void emit(const(string) outputDirectory, ref BuildCollector col) @system
    {
        import std.stdio;
        import std.algorithm;

        packages.values.each!((p) => emitPackage(outputDirectory, p, col));
    }

private:

    /**
     * Emit a single package into the given working directory
     */
    final void emitPackage(const(string) outputDirectory, scope Package* pkg, ref BuildCollector col) @trusted
    {
        import std.stdio;
        import std.path : buildPath;
        import std.algorithm;
        import moss.format.binary : FileType;
        import std.array;

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
        auto writer = Writer(fp);
        scope (exit)
        {
            writer.close();
        }

        writefln("Creating package %s...", finalPath);

        /* Encode metapayload */
        auto meta = MetaPayload();
        meta.compression = PayloadCompression.Zstd;

        /* Add relevant entries */
        meta.addRecord(RecordTag.Name, pkg.pd.name);
        meta.addRecord(RecordTag.Version, pkg.source.versionIdentifier);
        meta.addRecord(RecordTag.Release, pkg.source.release);
        meta.addRecord(RecordTag.Summary, pkg.pd.summary);
        meta.addRecord(RecordTag.Description, pkg.pd.description);
        meta.addRecord(RecordTag.Homepage, pkg.source.homepage);
        writer.addPayload(cast(Payload*)&meta);

        /* Add content payload */
        auto content = ContentPayload();
        content.compression = PayloadCompression.Zstd;

        auto indexes = IndexPayload();
        indexes.compression = PayloadCompression.Zstd;

        import std.file : getSize;

        ulong startOffset = 0;

        /* Encode content in deduplicated fashion */
        foreach (ref origin; dupeSet)
        {
            auto hash = origin.hash;
            auto source = origin.originPath;
            if (content.hasFile(hash))
            {
                continue;
            }

            auto size = source.getSize();
            auto endOffset = startOffset + size;
            content.addFile(hash, source);
            auto idx = IndexEntry();
            idx.size = size;
            idx.start = startOffset;
            idx.end = endOffset;
            indexes.addEntry(idx, hash);
            startOffset = endOffset;
        }

        /* Apply layout to disk */
        auto layouts = LayoutPayload();
        layouts.compression = PayloadCompression.Zstd;

        /**
         * Convert a FileAnalysis into a LayoutEntry struct
         */
        LayoutEntry fromAnalysis(ref FileAnalysis fa)
        {
            LayoutEntry ret;
            auto st = fa.stat;
            ret.uid = st.st_uid;
            ret.gid = st.st_gid;
            ret.mode = st.st_mode;

            /* TODO: Set global timestamp */
            ret.time = st.st_mtime;
            ret.type = fa.type;

            return ret;
        }

        /**
         * Push a layout entry
         */
        void pushLayout(ref FileAnalysis fa)
        {
            auto le = fromAnalysis(fa);

            switch (fa.type)
            {
            case FileType.Regular:
            case FileType.Symlink:
                layouts.addEntry(le, fa.data, fa.path);
                break;
            case FileType.Directory:
                layouts.addEntry(le, fa.path);
                break;
            default:
                assert(0, "Unsupported filetype");
            }
        }

        fileSet.each!((ref fa) => pushLayout(fa));

        writer.addPayload(cast(Payload*)&indexes);
        writer.addPayload(cast(Payload*)&content);
        writer.addPayload(cast(Payload*)&layouts);

        writer.flush();
    }

    Package*[string] packages;
}
