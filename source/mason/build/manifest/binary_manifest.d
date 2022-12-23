/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.manifest.binary_manifest
 *
 * Document binary build information
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest.binary_manifest;

public import mason.build.manifest;

import mason.build.context;
import moss.format.binary.archive_header;
import moss.format.binary.payload.meta;
import moss.format.binary.payload;
import moss.format.binary.writer;
import std.algorithm : sort, substitute, uniq;
import std.array : array, join;
import std.format : format;

/**
 * Binary, read-write implementation of the BuildManifest
 */
final class BuildManifestBinary : BuildManifest
{

    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture) @safe
    {
        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.bin".format(architecture.substitute!("/", "-"));
        this.arch = architecture;
    }

    override void recordPackage(scope Package* pkg, scope AnalysisBucket bucket,
            scope LayoutPayload lp) @safe
    {
        /* Same metadata as .stone */
        auto met = generateMetadata(bucket, pkg, false);
        auto buildDeps = buildContext.spec.rootBuild.buildDependencies
            ~ buildContext.spec.rootBuild.checkDependencies;
        buildDeps.sort();
        buildDeps = buildDeps.uniq.array;
        foreach (d; buildDeps)
        {
            () @trusted {
                met.addRecord(RecordType.Dependency, RecordTag.BuildDepends,
                        fromString!Dependency(d));
            }();
        }
        payloads ~= met;
    }

    override void write() @safe
    {
        import std.algorithm : each;

        auto targetPath = join([buildContext.outputDirectory, fileName], "/");
        auto fp = File(targetPath, "w");
        auto writer = new Writer(fp);
        writer.compressionType = PayloadCompression.Zstd;
        writer.fileType = MossFileType.BuildManifest;
        scope (exit)
        {
            writer.close();
        }
        foreach (p; payloads)
        {
            writer.addPayload(p);
        }
        writer.flush();
    }

private:

    MetaPayload[] payloads;
    string arch;
}
