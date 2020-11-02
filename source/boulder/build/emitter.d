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

import moss.format.source.packageDefinition;
import moss.format.source.sourceDefinition;
import moss.format.binary.writer;
import moss.format.binary.payload;
import moss.format.binary.contentPayload;
import moss.format.binary.index;
import moss.format.binary.indexPayload;
import moss.format.binary.metaPayload;
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

    /**
     * Add a file to the Package
     */
    final void addFile(const(string) relativePath, const(string) p) @safe
    {
        files ~= relativePath;
        _empty = false;

        import std.file;

        if (p.isFile && !p.isSymlink)
        {
            storeHash(p);
        }
    }

    /**
     * Return true if this is an empty (skippable) package
     */
    pure final @property bool empty() @safe @nogc nothrow
    {
        return _empty;
    }

    /**
     * Compute and store the hash for the file
     * We use the dupeStoreHash to ensure all identical files
     * are only added once
     */
    final void storeHash(const(string) p) @safe
    {
        auto hash = checkHash(p);
        if (hash in dupeHashStore)
        {
            return;
        }
        dupeHashStore[hash] = p;
    }

    /**
     * Ugly utility to check a hash
     */
    final string checkHash(const(string) path) @trusted
    {
        import std.stdio;
        import std.digest.sha;
        import std.string : toLower;

        auto sha = new SHA256Digest();
        auto input = File(path, "rb");
        foreach (ubyte[] buffer; input.byChunk(16 * 1024 * 1024))
        {
            sha.put(buffer);
        }
        return toHexString(sha.finish()).toLower();
    }

private:

    bool _empty = true;
    string[] files;

    /* Store hash -> source path here to only store once */
    string[string] dupeHashStore;
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

    final void addFile(const(string) pkgName, const(string) rp, const(string) fp) @safe
    {
        auto pkg = packages[pkgName];
        pkg.addFile(rp, fp);
    }

    /**
     * Now emit the collected packages
     */
    final void emit(const(string) outputDirectory) @system
    {
        import std.stdio;
        import std.algorithm;

        packages.values
            .filter!((p) => !p.empty)
            .each!((p) => emitPackage(outputDirectory, p));
    }

private:

    /**
     * Emit a single package into the given working directory
     */
    final void emitPackage(const(string) outputDirectory, scope Package* pkg) @trusted
    {
        import std.stdio;
        import std.path : buildPath;

        auto finalPath = outputDirectory.buildPath(pkg.filename);

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

        writefln("Encoding content");
        import std.file : getSize;

        ulong startOffset = 0;

        foreach (hash, source; pkg.dupeHashStore)
        {
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
        writer.addPayload(cast(Payload*)&indexes);
        writer.addPayload(cast(Payload*)&content);

        writer.flush();
    }

    Package*[string] packages;
}
